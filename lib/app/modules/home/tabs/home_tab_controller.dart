import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../../data/providers/location_provider.dart';
import '../../../services/auth_service.dart';
import '../../../utils/safe_ui.dart';

class HomeTabController extends GetxController {
  final AuthService _auth = Get.find<AuthService>();
  final LocationProvider _locationProvider = Get.find<LocationProvider>();

  final isTracking = false.obs;
  final isSending = false.obs;
  final currentPosition = Rxn<Position>();
  final lastLocationText = '--'.obs;
  final accuracyText = '--'.obs;
  final statusText = 'Detenido'.obs;

  /// Lista opcional para mostrar recorrido en polilínea.
  final routePoints = <Position>[].obs;

  StreamSubscription<Position>? _positionStream;
  DateTime? _lastSentAt;

  /// Iniciar tracking en primer plano.
  ///
  /// Esta versión prioriza estabilidad para pruebas reales:
  /// - pide permiso GPS al presionar "Iniciar Tracking";
  /// - valida que el GPS del teléfono esté activo;
  /// - actualiza el mapa en tiempo real;
  /// - envía cada punto al backend Laravel, que luego guarda en MongoDB.
  Future<void> startTracking() async {
    if (isTracking.value) return;

    final ready = await _ensureLocationReady();
    if (!ready) return;

    final token = _auth.token.value;
    if (token.isEmpty) {
      _showMessage(
        'Sesión requerida',
        'Vuelve a iniciar sesión para enviar ubicación.',
      );
      return;
    }

    try {
      isTracking.value = true;
      statusText.value = 'Solicitando ubicación...';

      final initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _updateAndSend(initialPosition, source: 'mobile_initial');

      _positionStream =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 5,
            ),
          ).listen(
            (position) async {
              await _updateAndSend(position, source: 'mobile_foreground');
            },
            onError: (error) {
              statusText.value = 'Error de GPS';
              _showMessage('Error de ubicación', error.toString());
            },
            cancelOnError: false,
          );

      statusText.value = 'En curso';
      debugPrint('▶️ Tracking iniciado');
    } catch (e) {
      isTracking.value = false;
      statusText.value = 'Detenido';
      _showMessage('No se pudo iniciar tracking', e.toString());
    }
  }

  /// Detener tracking.
  Future<void> stopTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;

    isTracking.value = false;
    isSending.value = false;
    statusText.value = 'Detenido';

    debugPrint('⏹ Tracking detenido');
  }

  Future<bool> _ensureLocationReady() async {
    // Android 13+ puede solicitar permiso de notificación.
    // No bloquea el tracking si el usuario lo niega, pero ayuda cuando luego se active background.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await ph.Permission.notification.request();
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Get.defaultDialog(
        title: 'GPS desactivado',
        middleText:
            'Activa la ubicación del teléfono para iniciar el tracking.',
        textConfirm: 'Abrir ajustes',
        textCancel: 'Cancelar',
        confirmTextColor: Colors.white,
        onConfirm: () async {
          Get.back();
          await Geolocator.openLocationSettings();
        },
      );
      statusText.value = 'GPS desactivado';
      return false;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      statusText.value = 'Permiso denegado';
      _showMessage(
        'Permiso requerido',
        'Debes permitir el acceso a la ubicación.',
      );
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      await Get.defaultDialog(
        title: 'Permiso bloqueado',
        middleText:
            'El permiso de ubicación está bloqueado. Actívalo manualmente desde los ajustes de la aplicación.',
        textConfirm: 'Abrir ajustes',
        textCancel: 'Cancelar',
        confirmTextColor: Colors.white,
        onConfirm: () async {
          Get.back();
          await Geolocator.openAppSettings();
        },
      );
      statusText.value = 'Permiso bloqueado';
      return false;
    }

    return true;
  }

  Future<void> _updateAndSend(
    Position position, {
    required String source,
  }) async {
    _updatePosition(position);

    // Evita saturar el backend si el stream emite varios puntos muy seguidos.
    final now = DateTime.now();
    if (_lastSentAt != null && now.difference(_lastSentAt!).inSeconds < 5) {
      return;
    }
    _lastSentAt = now;

    final token = _auth.token.value;
    if (token.isEmpty) return;

    try {
      isSending.value = true;
      await _locationProvider.registerLocation(
        token: token,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
        heading: position.heading,
        isMocked: position.isMocked,
        source: source,
      );
      statusText.value = 'En curso';
    } catch (e) {
      statusText.value = 'Error de envío';
      debugPrint('Error enviando ubicación: $e');
    } finally {
      isSending.value = false;
    }
  }

  void _updatePosition(Position position) {
    currentPosition.value = position;
    lastLocationText.value = '${position.latitude}, ${position.longitude}';
    accuracyText.value = '${position.accuracy.toStringAsFixed(2)} m';
    routePoints.add(position);
  }

  void _showMessage(String title, String message) {
    SafeUi.snackbar(title, message);
  }

  @override
  void onClose() {
    _positionStream?.cancel();
    super.onClose();
  }
}
