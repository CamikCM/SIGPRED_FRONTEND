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

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Stream<Map<String, dynamic>> get locationUpdates {
    if (!isSupported) return Stream<Map<String, dynamic>>.empty();
    return _service
        .on('locationUpdate')
        .where((event) => event != null)
        .map((event) => Map<String, dynamic>.from(event!));
  }

  static Stream<Map<String, dynamic>> get statusUpdates {
    if (!isSupported) return Stream<Map<String, dynamic>>.empty();
    return _service
        .on('trackingStatus')
        .where((event) => event != null)
        .map((event) => Map<String, dynamic>.from(event!));
  }

  static Future<void> initializeService() async {
    if (!isSupported) return;

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
        message: 'El seguimiento en segundo plano está disponible en Android.',
      );
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      return const TrackingPermissionResult(
        allowed: false,
        message: 'Activa la ubicación del teléfono para iniciar la jornada.',
      );
    }

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
            'Selecciona “Permitir siempre” en los ajustes para mantener el GPS cuando la aplicación esté minimizada.',
      );
    }

    return const TrackingPermissionResult(
      allowed: true,
      message: 'Permisos de seguimiento concedidos.',
    );
  }

  static Future<void> openSettings() async {
    await openAppSettings();
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
    if (!isSupported) return false;
    return _service.isRunning();
  }

  static Future<void> stopTracking() async {
    if (!isSupported) return;
    await _storage.write(key: _activeKey, value: 'false');
    _service.invoke('stopService');
  }

  static Future<void> clearTrackingContext() async {
    await _storage.delete(key: _activeKey);
    await _storage.delete(key: _jornadaKey);
    await _storage.delete(key: _rutaKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _startedAtKey);
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
