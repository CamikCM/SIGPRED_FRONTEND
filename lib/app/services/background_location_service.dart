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
  static const double minimumDistanceMeters = 30;
  static const Duration heartbeatInterval = Duration(seconds: 60);
  static const double preferredAccuracyMeters = 50;
  static const Duration poorAccuracyFallbackInterval = Duration(minutes: 5);

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
  static double? _iosLastAcceptedLatitude;
  static double? _iosLastAcceptedLongitude;
  static DateTime? _iosLastAcceptedAt;

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isSupported => isAndroid || isIos;

  static String get trackingModeDescription {
    if (isIos) {
      return 'GPS en segundo plano activo en iPhone · '
          'guarda cada 30 m o 60 s';
    }

    return 'GPS activo · consulta cada ${trackingInterval.inSeconds}s · '
        'guarda cada 30 m o 60 s';
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

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }

  static bool _shouldStorePoint({
    required double latitude,
    required double longitude,
    required double accuracy,
    required DateTime capturedAt,
    required bool force,
    required double? lastLatitude,
    required double? lastLongitude,
    required DateTime? lastCapturedAt,
  }) {
    if (force) return true;

    if (lastLatitude == null ||
        lastLongitude == null ||
        lastCapturedAt == null) {
      return true;
    }

    var elapsed = capturedAt.difference(lastCapturedAt);
    if (elapsed.isNegative) elapsed = Duration.zero;

    final hasPreferredAccuracy = accuracy <= preferredAccuracyMeters;
    if (!hasPreferredAccuracy && elapsed < poorAccuracyFallbackInterval) {
      return false;
    }

    final distance = Geolocator.distanceBetween(
      lastLatitude,
      lastLongitude,
      latitude,
      longitude,
    );

    return distance >= minimumDistanceMeters || elapsed >= heartbeatInterval;
  }

  static Future<Position?> _currentEventPosition() async {
    try {
      final settings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      );
      return await Geolocator.getCurrentPosition(
        locationSettings: settings,
      ).timeout(const Duration(seconds: 20));
    } catch (error) {
      debugPrint('⚠️ No se pudo capturar punto GPS de evento: $error');
      return null;
    }
  }

  static Future<bool> _captureForegroundEvent({
    required Position position,
    required String source,
  }) async {
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

    if (token == null || token.isEmpty) {
      queuedOffline = true;
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
          return false;
        }

        if (response.statusCode >= 400 && response.statusCode < 500) {
          debugPrint(
            '⚠️ Punto GPS de evento rechazado · '
            'HTTP ${response.statusCode}: ${response.body}',
          );
          return false;
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (error) {
        queuedOffline = true;
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

    debugPrint(
      '📌 GPS evento $source · '
      '${queuedOffline ? 'guardado offline' : 'enviado'} · '
      '${position.latitude.toStringAsFixed(6)}, '
      '${position.longitude.toStringAsFixed(6)}',
    );
    return true;
  }

  static Future<bool> captureEvent({
    required String source,
    Position? position,
    bool preferForeground = false,
  }) async {
    if (!isSupported) return false;

    final eventPosition = position ?? await _currentEventPosition();
    if (eventPosition == null) return false;

    if (preferForeground) {
      return _captureForegroundEvent(position: eventPosition, source: source);
    }

    final active = await _storage.read(key: _activeKey);

    if (isIos && active == 'true' && _iosPositionSubscription != null) {
      return _captureIosPosition(eventPosition, source: source, force: true);
    }

    if (isAndroid && active == 'true' && await _service.isRunning()) {
      final requestId = DateTime.now().microsecondsSinceEpoch.toString();
      final completer = Completer<bool>();
      late final StreamSubscription<Map<String, dynamic>?> subscription;

      subscription = _service.on('captureCompleted').listen((event) {
        if (event == null || event['request_id']?.toString() != requestId) {
          return;
        }
        if (!completer.isCompleted) {
          completer.complete(_toBool(event['captured']));
        }
      });

      _service.invoke('captureNow', {
        'request_id': requestId,
        'source': source,
        'latitude': eventPosition.latitude,
        'longitude': eventPosition.longitude,
        'accuracy': eventPosition.accuracy,
        'speed': eventPosition.speed,
        'heading': eventPosition.heading,
        'is_mocked': eventPosition.isMocked,
        'captured_at': DateTime.now().toIso8601String(),
      });

      try {
        return await completer.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () => false,
        );
      } finally {
        await subscription.cancel();
      }
    }

    // Fallback para eventos obligatorios cuando la jornada está pausada o
    // el servicio en segundo plano todavía no está disponible.
    return _captureForegroundEvent(position: eventPosition, source: source);
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
    _iosLastAcceptedLatitude = null;
    _iosLastAcceptedLongitude = null;
    _iosLastAcceptedAt = null;

    final settings = AppleSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      activityType: ActivityType.fitness,
      distanceFilter: 5,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
      allowBackgroundLocationUpdates: true,
    );

    try {
      final initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      ).timeout(const Duration(seconds: 20));
      await _captureIosPosition(
        initialPosition,
        source: 'jornada_tracking_inicio',
        force: true,
      );
    } catch (error) {
      debugPrint('⚠️ No se pudo obtener el primer punto iOS: $error');
    }

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

  static Future<bool> _captureIosPosition(
    Position position, {
    required String source,
    bool force = false,
  }) async {
    if (_iosCaptureInProgress) {
      if (!force) return false;
      final deadline = DateTime.now().add(const Duration(seconds: 12));
      while (_iosCaptureInProgress && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (_iosCaptureInProgress) return false;
    }

    _iosCaptureInProgress = true;

    try {
      final active = await _storage.read(key: _activeKey);

      if (active != 'true') {
        await _iosPositionSubscription?.cancel();
        _iosPositionSubscription = null;
        return false;
      }

      final permission = await Geolocator.checkPermission();

      if (permission != LocationPermission.always) {
        _emitIosStatus(
          'permission_error',
          'SIGPRED necesita permiso “Siempre” para '
              'continuar el seguimiento en iPhone.',
        );
        return false;
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        _emitIosStatus(
          'gps_disabled',
          'La ubicación del iPhone está desactivada.',
        );
        return false;
      }

      final capturedAt = DateTime.now();
      final shouldStore = _shouldStorePoint(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        capturedAt: capturedAt,
        force: force,
        lastLatitude: _iosLastAcceptedLatitude,
        lastLongitude: _iosLastAcceptedLongitude,
        lastCapturedAt: _iosLastAcceptedAt,
      );

      if (!shouldStore) {
        debugPrint('↪️ iOS GPS omitido · sin 30 m / 60 s o precisión > 50 m');
        return false;
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
        'captured_at': capturedAt.toIso8601String(),
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
            return false;
          }

          if (response.statusCode >= 400 && response.statusCode < 500) {
            _emitIosStatus(
              'validation_error',
              'El servidor rechazó el punto GPS '
                  '(HTTP ${response.statusCode}).',
            );
            return false;
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

      _iosLastAcceptedLatitude = position.latitude;
      _iosLastAcceptedLongitude = position.longitude;
      _iosLastAcceptedAt = capturedAt;

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
      return true;
    } catch (error, stackTrace) {
      debugPrint('❌ Error de tracking GPS iOS: $error');

      debugPrintStack(stackTrace: stackTrace);

      _emitIosStatus(
        'temporary_error',
        'Error temporal de GPS. '
            'SIGPRED continuará intentando.',
      );
      return false;
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
  double? lastAcceptedLatitude;
  double? lastAcceptedLongitude;
  DateTime? lastAcceptedAt;

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

  Future<bool> captureLocation({
    required String source,
    bool force = false,
    Map<String, dynamic>? provided,
  }) async {
    if (captureInProgress) {
      if (!force) return false;
      final deadline = DateTime.now().add(const Duration(seconds: 12));
      while (captureInProgress && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (captureInProgress) return false;
    }
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
        return false;
      }

      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        await updateNotification('Permiso de ubicación no disponible');
        await emitStatus(
          'permission_error',
          'Permiso de ubicación no disponible.',
        );
        return false;
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        await updateNotification('GPS desactivado · esperando ubicación');
        await emitStatus(
          'gps_disabled',
          'El GPS del teléfono está desactivado.',
        );
        return false;
      }

      final providedLatitude = BackgroundLocationService._toDouble(
        provided?['latitude'],
      );
      final providedLongitude = BackgroundLocationService._toDouble(
        provided?['longitude'],
      );

      late final double latitude;
      late final double longitude;
      late final double accuracy;
      late final double speed;
      late final double heading;
      late final bool isMocked;
      late final DateTime capturedAt;

      if (providedLatitude != null && providedLongitude != null) {
        latitude = providedLatitude;
        longitude = providedLongitude;
        accuracy =
            BackgroundLocationService._toDouble(provided?['accuracy']) ?? 0;
        speed = BackgroundLocationService._toDouble(provided?['speed']) ?? 0;
        heading =
            BackgroundLocationService._toDouble(provided?['heading']) ?? 0;
        isMocked = BackgroundLocationService._toBool(provided?['is_mocked']);
        capturedAt =
            DateTime.tryParse(provided?['captured_at']?.toString() ?? '') ??
            DateTime.now();
      } else {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
          ),
        ).timeout(const Duration(seconds: 20));
        latitude = position.latitude;
        longitude = position.longitude;
        accuracy = position.accuracy;
        speed = position.speed;
        heading = position.heading;
        isMocked = position.isMocked;
        capturedAt = DateTime.now();
      }

      final shouldStore = BackgroundLocationService._shouldStorePoint(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        capturedAt: capturedAt,
        force: force,
        lastLatitude: lastAcceptedLatitude,
        lastLongitude: lastAcceptedLongitude,
        lastCapturedAt: lastAcceptedAt,
      );

      if (!shouldStore) {
        debugPrint(
          '↪️ GPS omitido · sin 30 m / 60 s o precisión > 50 m · '
          'source=$source',
        );
        return false;
      }

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
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'speed': speed,
        'heading': heading,
        'is_mocked': isMocked,
        'source': source,
        'captured_at': capturedAt.toIso8601String(),
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
            return false;
          }

          if (response.statusCode >= 400 && response.statusCode < 500) {
            await updateNotification(
              'GPS activo · el servidor rechazó el punto',
            );
            await emitStatus(
              'validation_error',
              'HTTP ${response.statusCode}: ${response.body}',
            );
            return false;
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

      lastAcceptedLatitude = latitude;
      lastAcceptedLongitude = longitude;
      lastAcceptedAt = capturedAt;

      pointCount += 1;
      final stateText = queuedOffline ? 'guardado offline' : 'enviado';

      debugPrint(
        '📍 GPS #$pointCount $stateText · source=$source · '
        '${latitude.toStringAsFixed(6)}, '
        '${longitude.toStringAsFixed(6)}',
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
      return true;
    } catch (error, stackTrace) {
      debugPrint('❌ Error capturando/enviando GPS: $error');
      debugPrintStack(stackTrace: stackTrace);
      await updateNotification('GPS activo · error temporal · reintentando');
      await emitStatus('temporary_error', error.toString());
      return false;
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

  service.on('captureNow').listen((event) async {
    final data = event == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(event);
    final requestId = data['request_id']?.toString() ?? '';
    final source = data['source']?.toString().trim();
    final captured = await captureLocation(
      source: source == null || source.isEmpty ? 'tracking_event' : source,
      force: true,
      provided: data,
    );
    service.invoke('captureCompleted', {
      'request_id': requestId,
      'captured': captured,
    });
  });

  final active = await storage.read(key: 'sigpred_tracking_active');
  if (active != 'true') {
    service.stopSelf();
    return;
  }

  await updateNotification('GPS activo · esperando primer punto...');
  await captureLocation(source: 'jornada_tracking_inicio', force: true);

  timer = Timer.periodic(BackgroundLocationService.trackingInterval, (_) async {
    await captureLocation(source: 'jornada_tracking_background');
  });
}
