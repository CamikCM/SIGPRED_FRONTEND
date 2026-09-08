import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import '../data/local/local_database.dart';
import '../utils/env.dart';

class TrackingPermissionResult {
  const TrackingPermissionResult({
    required this.allowed,
    required this.message,
  });

  final bool allowed;
  final String message;
}

class BackgroundLocationService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String notificationChannelId = 'sigpred_tracking';
  static const int notificationId = 918;
  static const Duration trackingInterval = Duration(seconds: 15);

  static const String _activeKey = 'sigpred_tracking_active';
  static const String _jornadaKey = 'sigpred_tracking_jornada_id';
  static const String _rutaKey = 'sigpred_tracking_ruta_id';
  static const String _userKey = 'sigpred_tracking_user_id';
  static const String _startedAtKey = 'sigpred_tracking_started_at';

  // iOS usa Core Location directamente mediante Geolocator.
  // Android conserva flutter_background_service.
  static final StreamController<Map<String, dynamic>> _iosLocationController =
      StreamController<Map<String, dynamic>>.broadcast();

  static final StreamController<Map<String, dynamic>> _iosStatusController =
      StreamController<Map<String, dynamic>>.broadcast();

  static StreamSubscription<Position>? _iosPositionSubscription;
  static int _iosPointCount = 0;
  static bool _iosCaptureInProgress = false;

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isSupported => isAndroid || isIos;

  static String get trackingModeDescription {
    if (isIos) {
      return 'GPS en segundo plano activo en iPhone · '
          'actualizaciones administradas por iOS';
    }

    return 'GPS en segundo plano activo cada '
        '${trackingInterval.inSeconds}s';
  }

  static Stream<Map<String, dynamic>> get locationUpdates {
    if (isAndroid) {
      return _service
          .on('locationUpdate')
          .where((event) => event != null)
          .map((event) => Map<String, dynamic>.from(event!));
    }

    if (isIos) {
      return _iosLocationController.stream;
    }

    return Stream<Map<String, dynamic>>.empty();
  }

  static Stream<Map<String, dynamic>> get statusUpdates {
    if (isAndroid) {
      return _service
          .on('trackingStatus')
          .where((event) => event != null)
          .map((event) => Map<String, dynamic>.from(event!));
    }

    if (isIos) {
      return _iosStatusController.stream;
    }

    return Stream<Map<String, dynamic>>.empty();
  }

  static Future<void> initializeService() async {
    // En iPhone el seguimiento se hace directamente mediante Core Location.
    // flutter_background_service se conserva exclusivamente para Android.
    if (!isAndroid) return;

    const channel = AndroidNotificationChannel(
      notificationChannelId,
      'Seguimiento de jornada SIGPRED',
      description:
          'Mantiene visible el seguimiento GPS mientras la jornada está activa.',
      importance: Importance.low,
    );

    final notifications = FlutterLocalNotificationsPlugin();

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await notifications.initialize(initializationSettings);

    await notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        autoStartOnBoot: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'SIGPRED · Jornada activa',
        initialNotificationContent: 'Preparando seguimiento GPS...',
        foregroundServiceNotificationId: notificationId,
        foregroundServiceTypes: const [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
      ),
    );
  }

  static Future<TrackingPermissionResult> ensurePermissions() async {
    if (!isSupported) {
      return const TrackingPermissionResult(
        allowed: false,
        message:
            'El seguimiento en segundo plano está disponible en Android y iPhone.',
      );
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      return const TrackingPermissionResult(
        allowed: false,
        message: 'Activa la ubicación del teléfono para iniciar la jornada.',
      );
    }

    if (isAndroid) {
      final notificationStatus = await Permission.notification.status;

      if (!notificationStatus.isGranted) {
        await Permission.notification.request();
      }

      var foregroundStatus = await Permission.locationWhenInUse.status;

      if (!foregroundStatus.isGranted) {
        foregroundStatus = await Permission.locationWhenInUse.request();
      }

      if (!foregroundStatus.isGranted) {
        return const TrackingPermissionResult(
          allowed: false,
          message:
              'Debes permitir la ubicación precisa para registrar la jornada.',
        );
      }

      var backgroundStatus = await Permission.locationAlways.status;

      if (!backgroundStatus.isGranted) {
        backgroundStatus = await Permission.locationAlways.request();
      }

      if (!backgroundStatus.isGranted) {
        return const TrackingPermissionResult(
          allowed: false,
          message:
              'Selecciona “Permitir siempre” en los ajustes para mantener '
              'el GPS cuando la aplicación esté minimizada.',
        );
      }

      return const TrackingPermissionResult(
        allowed: true,
        message: 'Permisos de seguimiento concedidos.',
      );
    }

    // iPhone: Geolocator/Core Location.
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return const TrackingPermissionResult(
        allowed: false,
        message:
            'La ubicación está bloqueada para SIGPRED. '
            'Abre Ajustes y habilita la ubicación.',
      );
    }

    // iOS puede conceder primero "Al usar la app".
    // Para seguimiento con la pantalla bloqueada/minimizada necesitamos Always.
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    if (permission != LocationPermission.always) {
      return const TrackingPermissionResult(
        allowed: false,
        message:
            'En iPhone selecciona “Siempre” para SIGPRED en '
            'Ajustes > Privacidad y seguridad > Localización.',
      );
    }

    return const TrackingPermissionResult(
      allowed: true,
      message: 'Permisos de seguimiento concedidos.',
    );
  }

  static Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }

  static Future<void> startTracking({
    required int userId,
    int? jornadaId,
    int? rutaId,
  }) async {
    if (!isSupported) return;

    await _storage.write(key: _activeKey, value: 'true');

    await _storage.write(key: _userKey, value: userId.toString());

    await _storage.write(key: _jornadaKey, value: jornadaId?.toString() ?? '');

    await _storage.write(key: _rutaKey, value: rutaId?.toString() ?? '');

    await _storage.write(
      key: _startedAtKey,
      value: DateTime.now().toIso8601String(),
    );

    if (isAndroid) {
      final running = await _service.isRunning();

      if (!running) {
        await _service.startService();
      } else {
        _service.invoke('updateContext', {
          'user_id': userId,
          'jornada_id': jornadaId,
          'ruta_id': rutaId,
        });
      }

      return;
    }

    await _startIosTracking();
  }

  static Future<void> restoreIfNeeded({
    required int userId,
    int? jornadaId,
    int? rutaId,
  }) async {
    if (!isSupported) return;

    final active = await _storage.read(key: _activeKey);

    if (active == 'true') {
      await startTracking(userId: userId, jornadaId: jornadaId, rutaId: rutaId);
    }
  }

  static Future<bool> isRunning() async {
    if (isAndroid) {
      return _service.isRunning();
    }

    if (isIos) {
      final active = await _storage.read(key: _activeKey);

      return active == 'true' && _iosPositionSubscription != null;
    }

    return false;
  }

  static Future<void> stopTracking() async {
    if (!isSupported) return;

    await _storage.write(key: _activeKey, value: 'false');

    if (isAndroid) {
      _service.invoke('stopService');
      return;
    }

    await _iosPositionSubscription?.cancel();
    _iosPositionSubscription = null;

    _emitIosStatus('stopped', 'Seguimiento GPS finalizado.');
  }

  static Future<void> clearTrackingContext() async {
    if (isIos) {
      await _iosPositionSubscription?.cancel();
      _iosPositionSubscription = null;
    }

    await _storage.delete(key: _activeKey);
    await _storage.delete(key: _jornadaKey);
    await _storage.delete(key: _rutaKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _startedAtKey);
  }

  static Future<void> _startIosTracking() async {
    await _iosPositionSubscription?.cancel();
    _iosPositionSubscription = null;

    _iosPointCount = 0;
    _iosCaptureInProgress = false;

    final settings = AppleSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      activityType: ActivityType.fitness,
      distanceFilter: 5,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
      allowBackgroundLocationUpdates: true,
    );

    _iosPositionSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen(
          (position) {
            unawaited(
              _captureIosPosition(position, source: 'jornada_tracking_ios'),
            );
          },
          onError: (Object error) {
            _emitIosStatus(
              'temporary_error',
              'Error de ubicación en iPhone: $error',
            );
          },
          cancelOnError: false,
        );

    _emitIosStatus('started', 'GPS de jornada activo en iPhone.');
  }

  static Future<void> _captureIosPosition(
    Position position, {
    required String source,
  }) async {
    if (_iosCaptureInProgress) return;

    _iosCaptureInProgress = true;

    try {
      final active = await _storage.read(key: _activeKey);

      if (active != 'true') {
        await _iosPositionSubscription?.cancel();
        _iosPositionSubscription = null;
        return;
      }

      final permission = await Geolocator.checkPermission();

      if (permission != LocationPermission.always) {
        _emitIosStatus(
          'permission_error',
          'SIGPRED necesita permiso “Siempre” para '
              'continuar el seguimiento en iPhone.',
        );
        return;
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        _emitIosStatus(
          'gps_disabled',
          'La ubicación del iPhone está desactivada.',
        );
        return;
      }

      final jornadaText = await _storage.read(key: _jornadaKey);

      final rutaText = await _storage.read(key: _rutaKey);

      final token = await _storage.read(key: 'token');

      final jornadaId = int.tryParse(jornadaText ?? '');

      final rutaId = int.tryParse(rutaText ?? '');

      final payload = <String, dynamic>{
        if (jornadaId != null) 'jornada_id': jornadaId,
        if (rutaId != null) 'ruta_id': rutaId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'is_mocked': position.isMocked,
        'source': source,
        'captured_at': DateTime.now().toIso8601String(),
      };

      var queuedOffline = false;
      String? networkError;

      if (token == null || token.isEmpty) {
        queuedOffline = true;
        networkError = 'Sesión no disponible';
      } else {
        try {
          final response = await http
              .post(
                Env.uri('/tracking/locations'),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode(payload),
              )
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 401 || response.statusCode == 403) {
            await _storage.write(key: _activeKey, value: 'false');

            _emitIosStatus(
              'session_error',
              'La sesión venció durante '
                  'el seguimiento GPS.',
            );

            await _iosPositionSubscription?.cancel();
            _iosPositionSubscription = null;
            return;
          }

          if (response.statusCode >= 400 && response.statusCode < 500) {
            _emitIosStatus(
              'validation_error',
              'El servidor rechazó el punto GPS '
                  '(HTTP ${response.statusCode}).',
            );
            return;
          }

          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw Exception(
              'HTTP ${response.statusCode}: '
              '${response.body}',
            );
          }
        } catch (error) {
          queuedOffline = true;
          networkError = error.toString();
        }
      }

      if (queuedOffline) {
        await LocalDatabase.instance.insertOfflineRecord(
          kind: 'tracking',
          method: 'POST',
          endpoint: '/tracking/locations',
          payload: payload,
        );
      }

      _iosPointCount += 1;

      final stateText = queuedOffline ? 'guardado offline' : 'enviado';

      debugPrint(
        '📍 iOS GPS #$_iosPointCount $stateText · '
        '${position.latitude.toStringAsFixed(6)}, '
        '${position.longitude.toStringAsFixed(6)}',
      );

      _iosLocationController.add({
        ...payload,
        'queued_offline': queuedOffline,
        'point_count': _iosPointCount,
        if (networkError != null) 'network_error': networkError,
      });

      _emitIosStatus(
        'tracking',
        'GPS activo · $_iosPointCount '
            '${_iosPointCount == 1 ? 'punto' : 'puntos'} · '
            'último $stateText',
      );
    } catch (error, stackTrace) {
      debugPrint('❌ Error de tracking GPS iOS: $error');

      debugPrintStack(stackTrace: stackTrace);

      _emitIosStatus(
        'temporary_error',
        'Error temporal de GPS. '
            'SIGPRED continuará intentando.',
      );
    } finally {
      _iosCaptureInProgress = false;
    }
  }

  static void _emitIosStatus(String status, String message) {
    if (!isIos) return;

    _iosStatusController.add({
      'status': status,
      'message': message,
      'captured_at': DateTime.now().toIso8601String(),
    });
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // AVANCE 10.1.3:
  // El servicio corre en un isolate separado. Para que el conteo visible
  // en Android se refresque de forma estable, actualizamos la MISMA
  // notificación foreground (mismo ID configurado en initializeService).
  final FlutterLocalNotificationsPlugin backgroundNotifications =
      FlutterLocalNotificationsPlugin();

  const storage = FlutterSecureStorage();
  final localDb = LocalDatabase.instance;
  Timer? timer;
  var pointCount = 0;
  var captureInProgress = false;

  Future<void> updateNotification(String content) async {
    if (service is! AndroidServiceInstance) return;

    final androidService = service;

    try {
      if (!await androidService.isForegroundService()) {
        androidService.setAsForegroundService();
      }

      // Se usa el MISMO ID configurado en AndroidConfiguration.
      // De esta forma Android/XOS actualiza la notificación existente
      // en vez de crear notificaciones nuevas.
      await backgroundNotifications.show(
        BackgroundLocationService.notificationId,
        'SIGPRED · Jornada activa',
        content,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            BackgroundLocationService.notificationChannelId,
            'Seguimiento de jornada SIGPRED',
            channelDescription:
                'Mantiene visible el seguimiento GPS durante la jornada.',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            onlyAlertOnce: true,
            showWhen: false,
          ),
        ),
      );

      debugPrint('🔔 SIGPRED tracking: $content');
    } catch (error) {
      debugPrint(
        '⚠️ No se pudo refrescar la notificación personalizada: $error',
      );

      // Fallback del propio flutter_background_service.
      try {
        androidService.setForegroundNotificationInfo(
          title: 'SIGPRED · Jornada activa',
          content: content,
        );
      } catch (fallbackError) {
        debugPrint(
          '⚠️ Tampoco se pudo refrescar la notificación foreground: '
          '$fallbackError',
        );
      }
    }
  }

  Future<void> emitStatus(String status, String message) async {
    service.invoke('trackingStatus', {
      'status': status,
      'message': message,
      'captured_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> captureLocation({required String source}) async {
    if (captureInProgress) return;
    captureInProgress = true;

    try {
      debugPrint(
        '🛰️ Background GPS isolate activo · intervalo '
        '${BackgroundLocationService.trackingInterval.inSeconds}s',
      );

      final active = await storage.read(key: 'sigpred_tracking_active');
      if (active != 'true') {
        timer?.cancel();
        await updateNotification('Jornada finalizada. Deteniendo GPS...');
        service.stopSelf();
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        await updateNotification('Permiso de ubicación no disponible');
        await emitStatus(
          'permission_error',
          'Permiso de ubicación no disponible.',
        );
        return;
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        await updateNotification('GPS desactivado · esperando ubicación');
        await emitStatus(
          'gps_disabled',
          'El GPS del teléfono está desactivado.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      ).timeout(const Duration(seconds: 20));

      final jornadaText = await storage.read(
        key: 'sigpred_tracking_jornada_id',
      );
      final rutaText = await storage.read(key: 'sigpred_tracking_ruta_id');
      final token = await storage.read(key: 'token');
      final jornadaId = int.tryParse(jornadaText ?? '');
      final rutaId = int.tryParse(rutaText ?? '');

      final payload = <String, dynamic>{
        if (jornadaId != null) 'jornada_id': jornadaId,
        if (rutaId != null) 'ruta_id': rutaId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'is_mocked': position.isMocked,
        'source': source,
        'captured_at': DateTime.now().toIso8601String(),
      };

      var queuedOffline = false;
      String? networkError;

      if (token == null || token.isEmpty) {
        queuedOffline = true;
        networkError = 'Sesión no disponible';
      } else {
        try {
          final response = await http
              .post(
                Env.uri('/tracking/locations'),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode(payload),
              )
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 401 || response.statusCode == 403) {
            await storage.write(key: 'sigpred_tracking_active', value: 'false');
            await updateNotification(
              'Sesión vencida · abre SIGPRED para continuar',
            );
            await emitStatus(
              'session_error',
              'La sesión venció durante el seguimiento GPS.',
            );
            timer?.cancel();
            service.stopSelf();
            return;
          }

          if (response.statusCode >= 400 && response.statusCode < 500) {
            await updateNotification(
              'GPS activo · el servidor rechazó el punto',
            );
            await emitStatus(
              'validation_error',
              'HTTP ${response.statusCode}: ${response.body}',
            );
            return;
          }

          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw Exception('HTTP ${response.statusCode}: ${response.body}');
          }
        } catch (error) {
          queuedOffline = true;
          networkError = error.toString();
        }
      }

      if (queuedOffline) {
        await localDb.insertOfflineRecord(
          kind: 'tracking',
          method: 'POST',
          endpoint: '/tracking/locations',
          payload: payload,
        );
      }

      pointCount += 1;
      final stateText = queuedOffline ? 'guardado offline' : 'enviado';

      debugPrint(
        '📍 GPS #$pointCount $stateText · source=$source · '
        '${position.latitude.toStringAsFixed(6)}, '
        '${position.longitude.toStringAsFixed(6)}',
      );

      await updateNotification(
        'GPS activo · $pointCount '
        '${pointCount == 1 ? 'punto' : 'puntos'} · último $stateText',
      );

      service.invoke('locationUpdate', {
        ...payload,
        'queued_offline': queuedOffline,
        'point_count': pointCount,
        if (networkError != null) 'network_error': networkError,
      });
    } catch (error, stackTrace) {
      debugPrint('❌ Error capturando/enviando GPS: $error');
      debugPrintStack(stackTrace: stackTrace);
      await updateNotification('GPS activo · error temporal · reintentando');
      await emitStatus('temporary_error', error.toString());
    } finally {
      captureInProgress = false;
    }
  }

  service.on('stopService').listen((event) async {
    timer?.cancel();
    await updateNotification('Seguimiento GPS finalizado');
    service.stopSelf();
  });

  service.on('updateContext').listen((event) async {
    await captureLocation(source: 'jornada_tracking_reanudado');
  });

  final active = await storage.read(key: 'sigpred_tracking_active');
  if (active != 'true') {
    service.stopSelf();
    return;
  }

  await updateNotification('GPS activo · esperando primer punto...');
  await captureLocation(source: 'jornada_tracking_inicio');

  timer = Timer.periodic(BackgroundLocationService.trackingInterval, (_) async {
    await captureLocation(source: 'jornada_tracking_background');
  });
}
