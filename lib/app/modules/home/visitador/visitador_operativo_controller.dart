import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/local_database.dart';
import '../../../data/models/pedido_item_draft.dart';
import '../../../data/models/visita_activa_draft.dart';
import '../../../data/providers/visitador_provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/background_location_service.dart';
import '../../../services/sync_service.dart';
import '../../../utils/safe_ui.dart';

class VisitadorOperativoController extends GetxController {
  final VisitadorProvider _provider = Get.find<VisitadorProvider>();
  final AuthService _auth = Get.find<AuthService>();
  final LocalDatabase _localDb = LocalDatabase.instance;
  final Uuid _uuid = const Uuid();

  SyncService? get _sync =>
      Get.isRegistered<SyncService>() ? Get.find<SyncService>() : null;

  final isLoading = false.obs;
  final isSubmitting = false.obs;
  final rutaHoy = Rxn<Map<String, dynamic>>();
  final jornadaHoy = Rxn<Map<String, dynamic>>();
  final productos = <Map<String, dynamic>>[].obs;
  final lastPosition = Rxn<Position>();
  final isGpsTracking = false.obs;
  final gpsStatusText = 'GPS detenido'.obs;
  final gpsPointsSent = 0.obs;
  final isUsingOfflineCache = false.obs;
  final visitaActiva = Rxn<VisitaActivaDraft>();
  final jornadaPausada = false.obs;

  // Regla operativa SIGPRED:
  // la visita se considera dentro del punto cuando el Visitador está
  // a 100 metros o menos de la ubicación registrada del cliente.
  static const double radioCumplimientoMetros = 100;
  static const double radioHabilitacionVisitaMetros = 100;

  StreamSubscription<Map<String, dynamic>>? _backgroundLocationSubscription;
  StreamSubscription<Map<String, dynamic>>? _backgroundStatusSubscription;
  Timer? _draftSaveDebounce;

  final observacionJornadaController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    _listenBackgroundTracking();
    unawaited(_restoreActiveVisit());
    unawaited(_sync?.refreshPendingCount());
    unawaited(refreshAll());
  }

  void _listenBackgroundTracking() {
    _backgroundLocationSubscription = BackgroundLocationService.locationUpdates
        .listen((event) {
          final latitude = _toDouble(event['latitude']);
          final longitude = _toDouble(event['longitude']);
          if (latitude != null && longitude != null) {
            lastPosition.value = Position(
              longitude: longitude,
              latitude: latitude,
              timestamp:
                  DateTime.tryParse(event['captured_at']?.toString() ?? '') ??
                  DateTime.now(),
              accuracy: _toDouble(event['accuracy']) ?? 0,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: _toDouble(event['heading']) ?? 0,
              headingAccuracy: 0,
              speed: _toDouble(event['speed']) ?? 0,
              speedAccuracy: 0,
              floor: null,
              isMocked: _toBool(event['is_mocked']),
            );
          }

          gpsPointsSent.value =
              _toInt(event['point_count']) ?? (gpsPointsSent.value + 1);
          final queued = _toBool(event['queued_offline']);
          isGpsTracking.value = true;
          gpsStatusText.value = queued
              ? 'GPS activo · último punto guardado offline'
              : 'GPS activo · ubicación enviada';
          unawaited(_sync?.refreshPendingCount());
        });

    _backgroundStatusSubscription = BackgroundLocationService.statusUpdates
        .listen((event) {
          final status = (event['status'] ?? '').toString();
          final message = (event['message'] ?? '').toString();
          if (status == 'gps_disabled') {
            gpsStatusText.value = 'GPS desactivado';
          } else if (status == 'permission_error') {
            gpsStatusText.value = 'Permiso de ubicación requerido';
          } else if (status == 'session_error') {
            isGpsTracking.value = false;
            gpsStatusText.value = 'Sesión vencida · GPS detenido';
          } else if (status == 'validation_error') {
            gpsStatusText.value = 'GPS activo · punto rechazado';
          } else if (message.isNotEmpty) {
            gpsStatusText.value = 'GPS activo · error temporal';
          }
        });
  }

  Future<void> refreshAll() async {
    isLoading.value = true;
    isUsingOfflineCache.value = false;

    Object? routeError;
    Object? jornadaError;
    Object? productosError;

    try {
      final ruta = await _provider.getRutaHoy();
      rutaHoy.value = ruta;
      await _localDb.saveJson(_cacheKey('ruta'), ruta);
    } catch (error) {
      routeError = error;
      rutaHoy.value = _asMapOrNull(
        await _localDb.readJson<dynamic>(_cacheKey('ruta')),
      );
      if (rutaHoy.value != null) isUsingOfflineCache.value = true;
    }

    try {
      final jornada = await _provider.getJornadaHoy();
      jornadaHoy.value = jornada;
      await _localDb.saveJson(_cacheKey('jornada'), jornada);
    } catch (error) {
      jornadaError = error;
      jornadaHoy.value = _asMapOrNull(
        await _localDb.readJson<dynamic>(_cacheKey('jornada')),
      );
      if (jornadaHoy.value != null) isUsingOfflineCache.value = true;
    }

    try {
      final catalogo = await _provider.getProductos();
      productos.assignAll(catalogo);
      await _localDb.saveJson(_cacheKey('productos'), catalogo);
    } catch (error) {
      productosError = error;
      final cached = await _localDb.readJson<dynamic>(_cacheKey('productos'));
      if (cached is List) {
        productos.assignAll(
          cached.whereType<Map>().map(
            (item) => Map<String, dynamic>.from(item),
          ),
        );
        if (productos.isNotEmpty) isUsingOfflineCache.value = true;
      }
    }

    final jornadaObservacion = jornadaHoy.value?['observacion']?.toString();
    if (observacionJornadaController.text.trim().isEmpty &&
        jornadaObservacion != null &&
        jornadaObservacion.trim().isNotEmpty) {
      observacionJornadaController.text = jornadaObservacion;
    }

    await _restoreActiveVisit();
    await _restorePauseState();

    if (jornadaActiva) {
      if (jornadaPausada.value) {
        await _stopGpsTracking();
      } else {
        unawaited(_resumeTrackingForActiveJornada());
      }
    } else if (jornadaError == null) {
      jornadaPausada.value = false;
      await _clearPauseState();
      await _stopGpsTracking();
    }

    isLoading.value = false;

    if (isUsingOfflineCache.value) {
      SafeUi.snackbar(
        'Modo offline',
        'Se cargaron la ruta, la jornada o el catálogo guardados en el teléfono.',
      );
    } else {
      final error = routeError ?? jornadaError ?? productosError;
      if (error != null && rutaHoy.value == null && jornadaHoy.value == null) {
        SafeUi.snackbar('No se pudo cargar la operación', _cleanError(error));
      }
    }
  }

  Future<void> iniciarJornada() async {
    if (isSubmitting.value) return;

    try {
      isSubmitting.value = true;

      final permission = await BackgroundLocationService.ensurePermissions();
      if (!permission.allowed) {
        gpsStatusText.value = 'Permiso de segundo plano requerido';
        SafeUi.snackbar('Permiso requerido', permission.message);
        return;
      }

      final position = await _getRequiredPosition();
      if (position == null) return;

      final response = await _provider.iniciarJornada(
        rutaId: rutaId,
        lat: position.latitude,
        lng: position.longitude,
        observacion: observacionJornadaController.text,
      );
      jornadaHoy.value = _asMapOrNull(response['data']) ?? response;
      await _localDb.saveJson(_cacheKey('jornada'), jornadaHoy.value);
      jornadaPausada.value = false;
      await _clearPauseState();

      await _startGpsTracking(initialPosition: position);
      SafeUi.snackbar(
        'Jornada iniciada',
        'Tus visitas pendientes se ordenarán por cercanía a tu ubicación.',
      );
    } catch (error) {
      final sync = _sync;
      if (sync != null && await _shouldQueueForOffline(error)) {
        final position = lastPosition.value;
        final payload = <String, dynamic>{
          if (rutaId != null) 'ruta_id': rutaId,
          if (position != null) 'lat': position.latitude,
          if (position != null) 'lng': position.longitude,
          if (observacionJornadaController.text.trim().isNotEmpty)
            'observacion': observacionJornadaController.text.trim(),
        };
        await sync.enqueueJornadaInicio(payload);
        jornadaHoy.value = _localJornada(
          inicio: true,
          lat: position?.latitude,
          lng: position?.longitude,
        );
        await _localDb.saveJson(_cacheKey('jornada'), jornadaHoy.value);
        jornadaPausada.value = false;
        await _clearPauseState();

        if (position != null) {
          await _startGpsTracking(initialPosition: position);
        }
        SafeUi.snackbar(
          'Jornada guardada offline',
          'La jornada y el GPS quedaron activos. Los datos se sincronizarán después.',
        );
      } else {
        SafeUi.snackbar('Error al iniciar jornada', _cleanError(error));
      }
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> cerrarJornada() async {
    if (isSubmitting.value) return;
    if (tieneVisitaActiva) {
      SafeUi.snackbar(
        'Visita en curso',
        'Finaliza o descarta la visita activa antes de cerrar la jornada.',
      );
      return;
    }

    try {
      isSubmitting.value = true;
      final position = await _tryGetPosition();
      await _recordTrackingEvent(
        'jornada_tracking_fin',
        position: position,
        waitForCompletion: true,
        preferForeground: true,
      );
      final response = await _provider.cerrarJornada(
        lat: position?.latitude,
        lng: position?.longitude,
        observacion: observacionJornadaController.text,
      );
      jornadaHoy.value = _asMapOrNull(response['data']) ?? response;
      await _localDb.saveJson(_cacheKey('jornada'), jornadaHoy.value);
      await _stopGpsTracking();
      jornadaPausada.value = false;
      await _clearPauseState();
      SafeUi.snackbar(
        'Jornada finalizada',
        'El cierre fue registrado y el seguimiento GPS se detuvo.',
      );
    } catch (error) {
      final sync = _sync;
      if (sync != null && await _shouldQueueForOffline(error)) {
        final position = lastPosition.value;
        final payload = <String, dynamic>{
          if (position != null) 'lat': position.latitude,
          if (position != null) 'lng': position.longitude,
          if (observacionJornadaController.text.trim().isNotEmpty)
            'observacion': observacionJornadaController.text.trim(),
        };
        await sync.enqueueJornadaCierre(payload);
        jornadaHoy.value = _localJornada(
          inicio: false,
          lat: position?.latitude,
          lng: position?.longitude,
        );
        await _localDb.saveJson(_cacheKey('jornada'), jornadaHoy.value);
        await _stopGpsTracking();
        jornadaPausada.value = false;
        await _clearPauseState();
        SafeUi.snackbar(
          'Cierre guardado offline',
          'El GPS se detuvo y el cierre se sincronizará después.',
        );
      } else {
        SafeUi.snackbar('Error al cerrar jornada', _cleanError(error));
      }
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<bool> registrarVisita({
    required Map<String, dynamic> detalleRuta,
    required DateTime fechaInicio,
    required String tipoAtencion,
    required bool efectiva,
    required String resultado,
    required String motivo,
    required String observaciones,
    required List<PedidoItemDraft> pedidoItems,
    required String? firmaBase64,
    required String firmaNombre,
    required String firmaRol,
    DateTime? firmaCapturedAt,
    DateTime? fechaEntrega,
    Position? posicionInicio,
  }) async {
    if (isSubmitting.value) return false;

    if (!jornadaActiva) {
      SafeUi.snackbar('Jornada requerida', 'Primero debes iniciar la jornada.');
      return false;
    }

    Map<String, dynamic>? pendingPayload;
    Position? trackingEndPosition;
    String? trackingEndSource;

    try {
      isSubmitting.value = true;
      await flushVisitaActiva();

      final activeDraft = visitaActiva.value;
      final cliente = _asMapOrNull(detalleRuta['cliente']) ?? detalleRuta;
      final posicionFin = await _tryGetPosition();
      final clienteLat = _toDouble(cliente['cliente_lat']);
      final clienteLng = _toDouble(
        cliente['cliente_lg'] ?? cliente['cliente_lng'],
      );
      final inicioLat = posicionInicio?.latitude ?? activeDraft?.inicioLat;
      final inicioLng = posicionInicio?.longitude ?? activeDraft?.inicioLng;
      final distanciaPunto = _distanceFromCoordinates(
        latitude: inicioLat ?? posicionFin?.latitude,
        longitude: inicioLng ?? posicionFin?.longitude,
        clienteLat: clienteLat,
        clienteLng: clienteLng,
      );
      const tipoAtencionFinal = 'Presencial';
      final cumplimientoRuta = distanciaPunto != null
          ? distanciaPunto <= radioCumplimientoMetros
          : null;

      final pedidoDetalles = pedidoItems
          .map((item) => item.toPayload())
          .toList();
      final efectivaFinal = pedidoDetalles.isNotEmpty;
      final esRevisita = activeDraft?.esRevisita == true;
      final visitaObjetivoId = activeDraft?.visitaId;
      final visitaObjetivoLocalUuid = activeDraft?.visitaLocalUuid;
      trackingEndPosition = posicionFin;
      trackingEndSource = esRevisita ? 'revisit_checkout' : 'visit_checkout';

      final payload = <String, dynamic>{
        if (esRevisita)
          'revision_uuid': activeDraft?.localUuid ?? _uuid.v4()
        else
          'local_uuid': activeDraft?.localUuid ?? _uuid.v4(),
        if (jornadaId != null) 'jor_id': jornadaId,
        if (_toInt(detalleRuta['ruta_det_id']) != null)
          'ruta_det_id': _toInt(detalleRuta['ruta_det_id']),
        'cliente_id':
            _toInt(cliente['cliente_id']) ?? _toInt(detalleRuta['cliente_id']),
        'fecha_inicio': fechaInicio.toIso8601String(),
        'fecha_fin': DateTime.now().toIso8601String(),
        'registro_visita_version': 3,
        'tipo_atencion': tipoAtencionFinal,
        'efectiva': efectivaFinal,
        'resultado': resultado.trim().isEmpty
            ? (efectivaFinal ? 'Pedido generado' : motivo.trim())
            : resultado.trim(),
        if (motivo.trim().isNotEmpty) 'motivo': motivo.trim(),
        if (observaciones.trim().isNotEmpty)
          'observaciones': observaciones.trim(),
        if (firmaBase64 != null && firmaBase64.trim().isNotEmpty)
          'firma_imagen': firmaBase64.trim(),
        if (firmaNombre.trim().isNotEmpty) 'firma_nombre': firmaNombre.trim(),
        if (firmaRol.trim().isNotEmpty) 'firma_rol': firmaRol.trim(),
        if (firmaCapturedAt != null)
          'firma_captured_at': firmaCapturedAt.toIso8601String(),
        if (inicioLat != null) 'inicio_lat': inicioLat,
        if (inicioLng != null) 'inicio_lng': inicioLng,
        if (posicionFin != null) 'fin_lat': posicionFin.latitude,
        if (posicionFin != null) 'fin_lng': posicionFin.longitude,
        if (posicionFin != null) 'lat': posicionFin.latitude,
        if (posicionFin != null) 'lng': posicionFin.longitude,
        if (distanciaPunto != null) 'distancia_punto_m': distanciaPunto,
        if (cumplimientoRuta != null) 'cumplimiento_ruta': cumplimientoRuta,
        if (pedidoDetalles.isNotEmpty)
          'pedido': {
            if (fechaEntrega != null)
              'fecha_entrega': DateFormat('yyyy-MM-dd').format(fechaEntrega),
            'observacion': 'Pedido registrado desde app móvil',
            'detalles': pedidoDetalles,
          },
      };

      pendingPayload = payload;

      if (esRevisita) {
        if (visitaObjetivoId != null) {
          await _provider.actualizarVisita(visitaObjetivoId, payload);
        } else if (visitaObjetivoLocalUuid != null &&
            visitaObjetivoLocalUuid.isNotEmpty) {
          final sync = _sync;
          if (sync == null) {
            throw Exception(
              'No se pudo acceder a la cola offline de la visita original.',
            );
          }

          final visitaAnteriorLocal = visitaRegistradaParaDetalle(detalleRuta);
          final replacementPayload = Map<String, dynamic>.from(payload)
            ..remove('revision_uuid')
            ..['local_uuid'] = visitaObjetivoLocalUuid;

          if (visitaAnteriorLocal != null && activeDraft != null) {
            replacementPayload['revisita_previa'] = {
              'revision_uuid': activeDraft.localUuid,
              'efectiva': visitaAnteriorLocal['efectiva'],
              'resultado': visitaAnteriorLocal['resultado'],
              'motivo': visitaAnteriorLocal['motivo'],
              'fecha_inicio': visitaAnteriorLocal['fecha_inicio'],
              'fecha_fin': visitaAnteriorLocal['fecha_fin'],
              'lat':
                  visitaAnteriorLocal['vis_lat'] ??
                  visitaAnteriorLocal['fin_lat'] ??
                  visitaAnteriorLocal['inicio_lat'],
              'lng':
                  visitaAnteriorLocal['vis_lng'] ??
                  visitaAnteriorLocal['fin_lng'] ??
                  visitaAnteriorLocal['inicio_lng'],
            };
          }

          final replaced = await sync.replacePendingVisita(
            localUuid: visitaObjetivoLocalUuid,
            payload: replacementPayload,
          );

          if (!replaced) {
            throw Exception(
              'La visita original todavía no tiene identificador del servidor. '
              'Sincroniza los pendientes e inténtalo nuevamente.',
            );
          }

          _updateLocalVisit(
            detalleRuta,
            replacementPayload,
            visitaLocalUuid: visitaObjetivoLocalUuid,
          );
          await _localDb.saveJson(_cacheKey('jornada'), jornadaHoy.value);
          await _recordTrackingEvent(
            trackingEndSource,
            position: trackingEndPosition,
          );
          await limpiarVisitaActiva();
          unawaited(sync.syncPending());
          SafeUi.snackbar(
            'Revisita actualizada',
            'Se actualizó la misma visita pendiente de sincronización.',
          );
          return true;
        } else {
          throw Exception(
            'No se encontró la visita original que se desea actualizar.',
          );
        }
      } else {
        await _provider.registrarVisita(payload);
      }

      await _recordTrackingEvent(
        trackingEndSource,
        position: trackingEndPosition,
      );
      await limpiarVisitaActiva();
      await refreshAll();
      SafeUi.snackbar(
        esRevisita ? 'Revisita actualizada' : 'Visita registrada',
        esRevisita
            ? 'La misma visita fue actualizada correctamente.'
            : 'Visita registrada.',
      );
      return true;
    } catch (error) {
      final sync = _sync;
      final activeDraft = visitaActiva.value;
      final esRevisita = activeDraft?.esRevisita == true;
      final visitaObjetivoId = activeDraft?.visitaId;

      if (sync != null &&
          pendingPayload != null &&
          await _shouldQueueForOffline(error)) {
        if (esRevisita && visitaObjetivoId != null) {
          await sync.enqueueVisitaUpdate(
            visitaId: visitaObjetivoId,
            payload: pendingPayload,
          );
          _updateLocalVisit(
            detalleRuta,
            pendingPayload,
            visitaId: visitaObjetivoId,
          );
          await _localDb.saveJson(_cacheKey('jornada'), jornadaHoy.value);
          if (trackingEndSource != null) {
            await _recordTrackingEvent(
              trackingEndSource,
              position: trackingEndPosition,
            );
          }
          await limpiarVisitaActiva();
          SafeUi.snackbar(
            'Revisita guardada offline',
            'La misma visita se actualizará cuando vuelva la conexión.',
          );
          return true;
        }

        if (!esRevisita) {
          await sync.enqueueVisita(pendingPayload);
          _addLocalVisit(detalleRuta, pendingPayload);
          await _localDb.saveJson(_cacheKey('jornada'), jornadaHoy.value);
          if (trackingEndSource != null) {
            await _recordTrackingEvent(
              trackingEndSource,
              position: trackingEndPosition,
            );
          }
          await limpiarVisitaActiva();
          SafeUi.snackbar(
            'Visita guardada offline',
            'La visita se conservará hasta que vuelva la conexión.',
          );
          return true;
        }
      }
      SafeUi.snackbar(
        esRevisita ? 'Error al actualizar visita' : 'Error al registrar visita',
        _cleanError(error),
      );
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  int? get rutaId => _toInt(rutaHoy.value?['ruta_id']);
  int? get jornadaId => _toInt(jornadaHoy.value?['jor_id']);

  bool get tieneRuta => rutaHoy.value != null;
  bool get tieneJornada => jornadaHoy.value != null;

  bool get jornadaActiva {
    final jornada = jornadaHoy.value;
    if (!tieneJornada || jornada == null) return false;
    final fin = jornada['jor_fin'];
    return fin == null || fin.toString().isEmpty;
  }

  bool get jornadaCerrada => tieneJornada && !jornadaActiva;
  bool get tieneVisitaActiva => visitaActiva.value != null;

  List<Map<String, dynamic>> get detallesRuta {
    final raw = rutaHoy.value?['detalles'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  Map<String, double>? _coordenadasDetalle(Map<String, dynamic> detalle) {
    final cliente = _asMapOrNull(detalle['cliente']) ?? detalle;

    final lat = _toDouble(
      cliente['cliente_lat'] ??
          cliente['lat'] ??
          cliente['latitude'] ??
          detalle['cliente_lat'] ??
          detalle['lat'] ??
          detalle['latitude'],
    );

    final lng = _toDouble(
      cliente['cliente_lng'] ??
          cliente['lng'] ??
          cliente['longitude'] ??
          detalle['cliente_lng'] ??
          detalle['lng'] ??
          detalle['longitude'],
    );

    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180 ||
        (lat == 0 && lng == 0)) {
      return null;
    }

    return <String, double>{'lat': lat, 'lng': lng};
  }

  double? distanciaADetalle(Map<String, dynamic> detalle) {
    final position = lastPosition.value;
    final coords = _coordenadasDetalle(detalle);
    if (position == null || coords == null) return null;

    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      coords['lat']!,
      coords['lng']!,
    );
  }

  String distanciaDetalleLabel(Map<String, dynamic> detalle) {
    final distance = distanciaADetalle(detalle);
    if (distance == null) return 'Distancia no disponible';

    if (distance < 1000) {
      return '${distance.round()} m';
    }

    return '${(distance / 1000).toStringAsFixed(1)} km';
  }

  double get radioHabilitacionActualMetros {
    return radioHabilitacionVisitaMetros;
  }

  bool detalleDentroDeRadio(Map<String, dynamic> detalle) {
    final distance = distanciaADetalle(detalle);
    if (distance == null) return false;
    return distance <= radioHabilitacionActualMetros;
  }

  List<Map<String, dynamic>> get detallesRutaOrdenados {
    final items = detallesRuta
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    items.sort((a, b) {
      final aVisitado = detalleVisitado(a);
      final bVisitado = detalleVisitado(b);

      if (aVisitado != bVisitado) {
        return aVisitado ? 1 : -1;
      }

      final da = distanciaADetalle(a);
      final db = distanciaADetalle(b);

      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;

      return da.compareTo(db);
    });

    return items;
  }

  Map<String, dynamic>? get siguienteVisitaSugerida {
    for (final detalle in detallesRutaOrdenados) {
      if (!detalleVisitado(detalle)) return detalle;
    }
    return null;
  }

  bool esMismoDetalle(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aDetalleId = _toInt(a['ruta_det_id']);
    final bDetalleId = _toInt(b['ruta_det_id']);

    if (aDetalleId != null && bDetalleId != null) {
      return aDetalleId == bDetalleId;
    }

    final aCliente = _asMapOrNull(a['cliente']);
    final bCliente = _asMapOrNull(b['cliente']);

    final aClienteId =
        _toInt(aCliente?['cliente_id']) ?? _toInt(a['cliente_id']);
    final bClienteId =
        _toInt(bCliente?['cliente_id']) ?? _toInt(b['cliente_id']);

    return aClienteId != null && bClienteId != null && aClienteId == bClienteId;
  }

  Future<void> actualizarUbicacionOperativa() async {
    final position = await _tryGetPosition(silent: true);

    if (position == null) {
      SafeUi.snackbar(
        'No pudimos obtener tu ubicación',
        'Verifica que la ubicación del teléfono esté activa e inténtalo nuevamente.',
      );
      return;
    }

    lastPosition.value = position;

    final siguiente = siguienteVisitaSugerida;
    if (siguiente == null) {
      SafeUi.snackbar('Ubicación actualizada', 'No quedan visitas pendientes.');
      return;
    }

    SafeUi.snackbar(
      'Ubicación actualizada',
      'La próxima visita sugerida está a ${distanciaDetalleLabel(siguiente)}.',
    );
  }

  String get _pauseCacheKey => _cacheKey('jornada_pausa');

  Future<void> _restorePauseState() async {
    try {
      final raw = await _localDb.readJson<dynamic>(_pauseCacheKey);
      if (raw is Map) {
        jornadaPausada.value = _toBool(raw['paused']);
      } else {
        jornadaPausada.value = _toBool(raw);
      }
    } catch (_) {
      jornadaPausada.value = false;
    }
  }

  Future<void> _savePauseState() async {
    await _localDb.saveJson(_pauseCacheKey, {
      'paused': jornadaPausada.value,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _clearPauseState() async {
    await _localDb.deleteJson(_pauseCacheKey);
  }

  Future<void> pausarJornada() async {
    if (!jornadaActiva || jornadaPausada.value || isSubmitting.value) return;
    if (tieneVisitaActiva) {
      SafeUi.snackbar(
        'Visita pendiente',
        'Guarda o cancela la visita actual antes de pausar la jornada.',
      );
      return;
    }
    try {
      isSubmitting.value = true;
      await _stopGpsTracking();
      jornadaPausada.value = true;
      await _savePauseState();
      SafeUi.snackbar(
        'Jornada pausada',
        'La ubicación se detuvo temporalmente. Puedes reanudar cuando vuelvas.',
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> reanudarJornada() async {
    if (!jornadaActiva || !jornadaPausada.value || isSubmitting.value) return;
    try {
      isSubmitting.value = true;
      final permission = await BackgroundLocationService.ensurePermissions();
      if (!permission.allowed) {
        SafeUi.snackbar('Permiso requerido', permission.message);
        return;
      }
      final position = await _getRequiredPosition();
      if (position == null) return;
      await _startGpsTracking(initialPosition: position);
      jornadaPausada.value = false;
      await _clearPauseState();
      SafeUi.snackbar('Jornada reanudada', 'La ubicación volvió a activarse.');
    } finally {
      isSubmitting.value = false;
    }
  }

  List<Map<String, dynamic>> get visitasRegistradas {
    final raw = jornadaHoy.value?['visitas'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  int get visitasRealizadas => visitasRegistradas.length;
  int get visitasPendientes =>
      (detallesRuta.length - visitasRealizadas).clamp(0, detallesRuta.length);

  bool detalleVisitado(Map<String, dynamic> detalle) =>
      visitaRegistradaParaDetalle(detalle) != null;

  Map<String, dynamic>? visitaRegistradaParaDetalle(
    Map<String, dynamic> detalle,
  ) {
    final detalleId = _toInt(detalle['ruta_det_id']);
    final cliente = _asMapOrNull(detalle['cliente']);
    final clienteId =
        _toInt(cliente?['cliente_id']) ?? _toInt(detalle['cliente_id']);

    for (final visita in visitasRegistradas.reversed) {
      final visitaDetalleId = _toInt(visita['ruta_det_id']);
      final visitaClienteId =
          _toInt(visita['cliente_id']) ??
          _toInt(_asMapOrNull(visita['cliente'])?['cliente_id']);
      if (detalleId != null && visitaDetalleId == detalleId) return visita;
      if (clienteId != null && visitaClienteId == clienteId) return visita;
    }

    return null;
  }

  bool detalleVisitaEfectiva(Map<String, dynamic> detalle) {
    final visita = visitaRegistradaParaDetalle(detalle);
    return visita != null && _toBool(visita['efectiva']);
  }

  String detalleMotivoVisita(Map<String, dynamic> detalle) {
    final visita = visitaRegistradaParaDetalle(detalle);
    return _text(visita?['motivo'], fallback: '');
  }

  bool detalleRevisitable(Map<String, dynamic> detalle) {
    final visita = visitaRegistradaParaDetalle(detalle);
    if (visita == null || _toBool(visita['efectiva'])) return false;

    final motivo = _text(visita['motivo'], fallback: '');
    return motivo != 'Sin pedido / atención realizada';
  }

  bool esDetalleVisitaActiva(Map<String, dynamic> detalle) {
    final active = visitaActiva.value;
    if (active == null) return false;
    final detalleId = _toInt(detalle['ruta_det_id']);
    final cliente = _asMapOrNull(detalle['cliente']);
    final clienteId =
        _toInt(cliente?['cliente_id']) ?? _toInt(detalle['cliente_id']);

    if (active.rutaDetalleId != null && detalleId != null) {
      return active.rutaDetalleId == detalleId;
    }
    return active.clienteId != null && active.clienteId == clienteId;
  }

  String get rutaNombre =>
      _text(rutaHoy.value?['ruta_nombre'], fallback: 'Ruta del día');

  String get zonaNombre {
    final zona = _asMapOrNull(rutaHoy.value?['zona']);
    return _text(zona?['zona_nombre'], fallback: 'Sin zona');
  }

  String clienteNombre(Map<String, dynamic> detalle) {
    final cliente = _asMapOrNull(detalle['cliente']) ?? detalle;
    return _text(cliente['cliente_nombre'], fallback: 'Punto de visita');
  }

  String clienteTipo(Map<String, dynamic> detalle) {
    final cliente = _asMapOrNull(detalle['cliente']) ?? detalle;
    final tipo =
        _asMapOrNull(cliente['tipo_cliente']) ??
        _asMapOrNull(cliente['tipoCliente']);
    return _text(
      tipo?['tc_nombre'] ?? cliente['tipo_cliente'] ?? cliente['tc_nombre'],
      fallback: 'Cliente',
    );
  }

  String clienteDireccion(Map<String, dynamic> detalle) {
    final cliente = _asMapOrNull(detalle['cliente']) ?? detalle;
    return _text(cliente['cliente_dir'], fallback: 'Sin dirección registrada');
  }

  String horaPlanificada(Map<String, dynamic> detalle) {
    return _text(detalle['hora_planificada'], fallback: '--:--');
  }

  String productoNombre(Map<String, dynamic> producto) {
    return _text(producto['producto_nombre'], fallback: 'Producto');
  }

  double productoPrecio(Map<String, dynamic> producto) {
    final value = producto['precio_referencial'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int? productoDisponibilidad(Map<String, dynamic> producto) {
    final value = producto['cantidad_disponible'];
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String get visitaActivaClienteNombre {
    final active = visitaActiva.value;
    if (active == null) return 'Sin visita activa';
    return clienteNombre(active.detalleRuta);
  }

  String get visitaActivaInicioLabel {
    final active = visitaActiva.value;
    if (active == null) return '--:--';
    return DateFormat('HH:mm').format(active.fechaInicio);
  }

  Duration get visitaActivaDuracion {
    final active = visitaActiva.value;
    if (active == null) return Duration.zero;
    return DateTime.now().difference(active.fechaInicio);
  }

  int get pendientesOffline => _sync?.pendingCount.value ?? 0;
  bool get sincronizandoOffline => _sync?.isSyncing.value ?? false;
  String get mensajeSyncOffline =>
      _sync?.lastSyncMessage.value ?? 'Sincronización lista';

  Future<void> actualizarPendientesOffline() async {
    await _sync?.refreshPendingCount();
  }

  Future<void> sincronizarPendientesOffline() async {
    final sync = _sync;
    if (sync == null) {
      SafeUi.snackbar(
        'Sincronización no disponible',
        'El servicio local no está iniciado.',
      );
      return;
    }

    await sync.refreshPendingCount();
    if (sync.pendingCount.value == 0) {
      SafeUi.snackbar(
        'Sin pendientes',
        'No existen registros offline por enviar.',
      );
      return;
    }

    final enviados = await sync.syncPending();
    if (enviados > 0) {
      await refreshAll();
      SafeUi.snackbar(
        'Sincronización completada',
        'Se enviaron $enviados registro(s). Pendientes: ${sync.pendingCount.value}.',
      );
    } else {
      SafeUi.snackbar('Sincronización pendiente', sync.lastSyncMessage.value);
    }
  }

  Future<void> actualizarUbicacionActual() async {
    final position = await _tryGetPosition();
    if (position == null) {
      SafeUi.snackbar(
        'Ubicación no disponible',
        'No se pudo obtener la ubicación actual.',
      );
      return;
    }
    lastPosition.value = position;
    SafeUi.snackbar(
      'Ubicación actualizada',
      'Ya puedes revisar nuevamente la distancia a tus visitas.',
    );
  }

  Future<VisitaActivaDraft?> iniciarORecuperarVisita(
    Map<String, dynamic> detalle, {
    bool revisita = false,
  }) async {
    final current = visitaActiva.value;
    if (current != null) {
      if (esDetalleVisitaActiva(detalle)) return current;
      SafeUi.snackbar(
        'Ya existe una visita activa',
        'Finaliza o descarta la visita de $visitaActivaClienteNombre antes de iniciar otra.',
      );
      return null;
    }

    if (!jornadaActiva) {
      SafeUi.snackbar('Jornada requerida', 'Primero debes iniciar la jornada.');
      return null;
    }

    final visitaAnterior = revisita
        ? visitaRegistradaParaDetalle(detalle)
        : null;

    if (revisita && !detalleRevisitable(detalle)) {
      SafeUi.snackbar(
        'Revisita no disponible',
        'Esta visita no puede volver a abrirse.',
      );
      return null;
    }

    final position = await _tryGetPosition(silent: true);
    final draft = VisitaActivaDraft(
      localUuid: _uuid.v4(),
      detalleRuta: Map<String, dynamic>.from(detalle),
      fechaInicio: DateTime.now(),
      inicioLat: position?.latitude,
      inicioLng: position?.longitude,
      visitaId: revisita ? _toInt(visitaAnterior?['vis_id']) : null,
      visitaLocalUuid: revisita
          ? _nullableString(visitaAnterior?['local_uuid'])
          : null,
      esRevisita: revisita,
      tipoAtencion: 'Presencial',
      efectiva: false,
      resultado: 'Visita realizada',
      motivo: '',
      observaciones: '',
      pedidoItems: const <PedidoItemDraft>[],
      firmaBase64: null,
      firmaNombre: null,
      firmaRol: null,
      firmaCapturedAt: null,
      updatedAt: DateTime.now(),
    );

    visitaActiva.value = draft;
    await _saveActiveVisitDraft();
    await _recordTrackingEvent(
      revisita ? 'revisit_checkin' : 'visit_checkin',
      position: position,
    );
    return draft;
  }

  void actualizarBorradorVisita({
    String? tipoAtencion,
    bool? efectiva,
    String? resultado,
    String? motivo,
    String? observaciones,
    List<PedidoItemDraft>? pedidoItems,
    DateTime? fechaEntrega,
    bool clearFechaEntrega = false,
    String? firmaBase64,
    bool clearFirma = false,
    String? firmaNombre,
    String? firmaRol,
    DateTime? firmaCapturedAt,
  }) {
    final current = visitaActiva.value;
    if (current == null) return;

    visitaActiva.value = current.copyWith(
      tipoAtencion: tipoAtencion,
      efectiva: efectiva,
      resultado: resultado,
      motivo: motivo,
      observaciones: observaciones,
      pedidoItems: pedidoItems == null
          ? null
          : List<PedidoItemDraft>.unmodifiable(pedidoItems),
      fechaEntrega: fechaEntrega,
      clearFechaEntrega: clearFechaEntrega,
      firmaBase64: firmaBase64,
      clearFirma: clearFirma,
      firmaNombre: firmaNombre,
      firmaRol: firmaRol,
      firmaCapturedAt: firmaCapturedAt,
      updatedAt: DateTime.now(),
    );

    _draftSaveDebounce?.cancel();
    _draftSaveDebounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_saveActiveVisitDraft()),
    );
  }

  Future<void> flushVisitaActiva() async {
    _draftSaveDebounce?.cancel();
    _draftSaveDebounce = null;
    await _saveActiveVisitDraft();
  }

  Future<void> limpiarVisitaActiva() async {
    _draftSaveDebounce?.cancel();
    _draftSaveDebounce = null;
    visitaActiva.value = null;
    await _localDb.deleteJson(_activeVisitCacheKey);
  }

  Future<void> descartarVisitaActiva() async {
    await limpiarVisitaActiva();
    SafeUi.snackbar(
      'Visita descartada',
      'El borrador activo fue eliminado del teléfono.',
    );
  }

  Future<void> _restoreActiveVisit() async {
    try {
      final raw = await _localDb.readJson<dynamic>(_activeVisitCacheKey);
      if (raw is Map) {
        final restored = VisitaActivaDraft.fromJson(
          Map<String, dynamic>.from(raw),
        );
        if (restored.localUuid.isNotEmpty && restored.detalleRuta.isNotEmpty) {
          visitaActiva.value = restored;
        }
      }
    } catch (error) {
      debugPrint('No se pudo recuperar la visita activa: $error');
    }
  }

  Future<void> _saveActiveVisitDraft() async {
    final draft = visitaActiva.value;
    if (draft == null) return;
    await _localDb.saveJson(_activeVisitCacheKey, draft.toJson());
  }

  Future<bool> _shouldQueueForOffline(Object error) async {
    final sync = _sync;
    if (sync == null) return false;
    if (!await sync.hasConnection()) return true;
    final message = error.toString().toLowerCase();
    return message.contains('socketexception') ||
        message.contains('timeoutexception') ||
        message.contains('clientexception') ||
        message.contains('connection refused') ||
        message.contains('failed host lookup') ||
        message.contains('connection reset') ||
        message.contains('connection closed');
  }

  Map<String, dynamic> _localJornada({
    required bool inicio,
    double? lat,
    double? lng,
  }) {
    final current = Map<String, dynamic>.from(
      jornadaHoy.value ?? <String, dynamic>{},
    );
    current['ruta_id'] = rutaId;
    current['jor_fecha'] = DateTime.now().toIso8601String();
    current['jor_inicio'] ??= DateTime.now().toIso8601String();
    if (!inicio) {
      current['jor_fin'] = DateTime.now().toIso8601String();
      if (lat != null) current['fin_lat'] = lat;
      if (lng != null) current['fin_lng'] = lng;
    } else {
      current['jor_fin'] = null;
      if (lat != null) current['inicio_lat'] = lat;
      if (lng != null) current['inicio_lng'] = lng;
    }
    current['offline'] = true;
    current['visitas'] ??= visitasRegistradas;
    return current;
  }

  void _addLocalVisit(
    Map<String, dynamic> detalleRuta,
    Map<String, dynamic> payload,
  ) {
    final jornada = Map<String, dynamic>.from(
      jornadaHoy.value ?? _localJornada(inicio: true),
    );
    final visitas = visitasRegistradas.toList();
    visitas.add({
      'vis_id': 'offline-${DateTime.now().millisecondsSinceEpoch}',
      'local_uuid': payload['local_uuid'],
      'jor_id': jornadaId,
      'ruta_det_id': payload['ruta_det_id'],
      'cliente_id': payload['cliente_id'],
      'cliente': _asMapOrNull(detalleRuta['cliente']),
      'fecha_inicio': payload['fecha_inicio'],
      'fecha_fin': payload['fecha_fin'],
      'tipo_atencion': payload['tipo_atencion'],
      'efectiva': payload['efectiva'],
      'resultado': payload['resultado'],
      'motivo': payload['motivo'],
      'observaciones': payload['observaciones'],
      'offline': true,
    });
    jornada['visitas'] = visitas;
    jornadaHoy.value = jornada;
  }

  void _updateLocalVisit(
    Map<String, dynamic> detalleRuta,
    Map<String, dynamic> payload, {
    int? visitaId,
    String? visitaLocalUuid,
  }) {
    final jornada = Map<String, dynamic>.from(
      jornadaHoy.value ?? _localJornada(inicio: true),
    );
    final visitas = visitasRegistradas.toList();

    final index = visitas.indexWhere((visita) {
      if (visitaId != null && _toInt(visita['vis_id']) == visitaId) {
        return true;
      }
      if (visitaLocalUuid != null &&
          visitaLocalUuid.isNotEmpty &&
          (visita['local_uuid'] ?? '').toString() == visitaLocalUuid) {
        return true;
      }

      final detalleId = _toInt(detalleRuta['ruta_det_id']);
      final visitaDetalleId = _toInt(visita['ruta_det_id']);
      if (detalleId != null && detalleId == visitaDetalleId) {
        return true;
      }

      final cliente = _asMapOrNull(detalleRuta['cliente']) ?? detalleRuta;
      final clienteId =
          _toInt(cliente['cliente_id']) ?? _toInt(detalleRuta['cliente_id']);
      final visitaClienteId = _toInt(visita['cliente_id']);
      return clienteId != null && clienteId == visitaClienteId;
    });

    if (index < 0) return;

    final current = Map<String, dynamic>.from(visitas[index]);
    current.addAll({
      'fecha_inicio': payload['fecha_inicio'],
      'fecha_fin': payload['fecha_fin'],
      'tipo_atencion': payload['tipo_atencion'],
      'efectiva': payload['efectiva'],
      'resultado': payload['resultado'],
      'motivo': payload['motivo'],
      'observaciones': payload['observaciones'],
      'inicio_lat': payload['inicio_lat'],
      'inicio_lng': payload['inicio_lng'],
      'fin_lat': payload['fin_lat'],
      'fin_lng': payload['fin_lng'],
      'vis_lat': payload['lat'] ?? payload['fin_lat'],
      'vis_lng': payload['lng'] ?? payload['fin_lng'],
      'distancia_punto_m': payload['distancia_punto_m'],
      'cumplimiento_ruta': payload['cumplimiento_ruta'],
      'offline': true,
    });

    visitas[index] = current;
    jornada['visitas'] = visitas;
    jornadaHoy.value = jornada;
  }

  Future<Position?> capturarPosicionInicioVisita() async {
    return _tryGetPosition(silent: true);
  }

  String get offlineStatusLabel => isUsingOfflineCache.value
      ? 'Datos locales disponibles'
      : 'Datos actualizados';

  String get _activeVisitCacheKey {
    final userId = _auth.currentUser.value?.id ?? 0;
    return 'visitador_${userId}_visita_activa';
  }

  String _cacheKey(String section) {
    final userId = _auth.currentUser.value?.id ?? 0;
    final date = DateFormat('yyyyMMdd').format(DateTime.now());
    return 'visitador_${userId}_${date}_$section';
  }

  double? _distanceFromCoordinates({
    required double? latitude,
    required double? longitude,
    required double? clienteLat,
    required double? clienteLng,
  }) {
    if (latitude == null ||
        longitude == null ||
        clienteLat == null ||
        clienteLng == null) {
      return null;
    }
    return Geolocator.distanceBetween(
      latitude,
      longitude,
      clienteLat,
      clienteLng,
    );
  }

  Future<Position?> _getRequiredPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        SafeUi.snackbar(
          'GPS requerido',
          'Activa la ubicación del teléfono para iniciar la jornada.',
        );
        await Geolocator.openLocationSettings();
        gpsStatusText.value = 'GPS desactivado';
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        SafeUi.snackbar(
          'Permiso requerido',
          'Debes permitir ubicación para iniciar la jornada.',
        );
        gpsStatusText.value = 'Permiso denegado';
        return null;
      }

      if (permission == LocationPermission.deniedForever) {
        SafeUi.snackbar(
          'Permiso bloqueado',
          'Activa el permiso de ubicación desde los ajustes.',
        );
        await Geolocator.openAppSettings();
        gpsStatusText.value = 'Permiso bloqueado';
        return null;
      }

      gpsStatusText.value = 'Obteniendo ubicación...';
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      lastPosition.value = position;
      return position;
    } catch (error) {
      gpsStatusText.value = 'Error de GPS';
      SafeUi.snackbar('No se pudo obtener GPS', _cleanError(error));
      return null;
    }
  }

  Future<void> _recordTrackingEvent(
    String source, {
    Position? position,
    bool waitForCompletion = false,
    bool preferForeground = false,
  }) async {
    if (!jornadaActiva) return;

    Future<void> capture() async {
      try {
        final captured = await BackgroundLocationService.captureEvent(
          source: source,
          position: position,
          preferForeground: preferForeground,
        );
        if (!captured) {
          debugPrint('⚠️ No se pudo registrar punto GPS obligatorio: $source');
        }
      } catch (error) {
        // El tracking nunca debe bloquear la operación comercial.
        debugPrint(
          '⚠️ Error registrando punto GPS obligatorio $source: $error',
        );
      }
    }

    if (waitForCompletion) {
      await capture();
    } else {
      unawaited(capture());
    }
  }

  Future<void> _resumeTrackingForActiveJornada() async {
    if (!jornadaActiva) return;

    final running = await BackgroundLocationService.isRunning();
    if (running) {
      isGpsTracking.value = true;
      gpsStatusText.value = 'GPS en segundo plano activo';
      await BackgroundLocationService.restoreIfNeeded(
        userId: _auth.currentUser.value?.id ?? 0,
        jornadaId: jornadaId,
        rutaId: rutaId,
      );
      return;
    }

    final permission = await BackgroundLocationService.ensurePermissions();
    if (!permission.allowed) {
      isGpsTracking.value = false;
      gpsStatusText.value = 'Permiso de segundo plano pendiente';
      return;
    }

    final position = await _tryGetPosition(silent: true);
    if (position == null) return;
    await _startGpsTracking(initialPosition: position);
  }

  Future<void> _startGpsTracking({required Position initialPosition}) async {
    final userId = _auth.currentUser.value?.id ?? 0;
    if (_auth.token.value.isEmpty || userId <= 0) {
      SafeUi.snackbar(
        'Sesión requerida',
        'Vuelve a iniciar sesión para enviar ubicación.',
      );
      return;
    }

    lastPosition.value = initialPosition;
    await BackgroundLocationService.startTracking(
      userId: userId,
      jornadaId: jornadaId,
      rutaId: rutaId,
    );
    isGpsTracking.value = true;
    gpsStatusText.value = BackgroundLocationService.trackingModeDescription;
  }

  Future<void> _stopGpsTracking() async {
    await BackgroundLocationService.stopTracking();
    isGpsTracking.value = false;
    gpsStatusText.value = 'GPS detenido';
  }

  Future<Position?> _tryGetPosition({bool silent = false}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent) {
          SafeUi.snackbar(
            'GPS desactivado',
            'Activa la ubicación para registrar coordenadas.',
          );
        }
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!silent) {
          SafeUi.snackbar(
            'Permiso de ubicación',
            'La operación continuará sin coordenadas GPS.',
          );
        }
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      lastPosition.value = position;
      return position;
    } catch (error) {
      if (!silent) {
        debugPrint('No se pudo obtener ubicación: $error');
      }
      return null;
    }
  }

  Map<String, dynamic>? _asMapOrNull(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase();
    return text == 'true' || text == '1';
  }

  String? _nullableString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  String _text(dynamic value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  // SIGPRED 10.25 - errores amigables para usuario final
  String _cleanError(Object error) {
    var text = error.toString().replaceFirst('Exception: ', '').trim();

    String unescape(String value) => value
        .replaceAll(r'\"', '"')
        .replaceAll(r'\n', ' ')
        .replaceAll(r'\/', '/')
        .trim();

    final detailMatch = RegExp(
      r'"pedido\.detalles"\s*:\s*\[\s*"([^"]+)"',
      caseSensitive: false,
    ).firstMatch(text);
    if (detailMatch != null) {
      return unescape(detailMatch.group(1)!);
    }

    final messageMatch = RegExp(
      r'"message"\s*:\s*"([^"]+)"',
      caseSensitive: false,
    ).firstMatch(text);
    if (messageMatch != null) {
      final message = unescape(messageMatch.group(1)!);
      if (message.isNotEmpty &&
          message.toLowerCase() != 'the given data was invalid.') {
        return message;
      }
    }

    text = text
        .replaceFirst(RegExp(r'^\[[^\]]+\]\s*\d{3}\s*:\s*'), '')
        .replaceFirst(RegExp(r'^HTTP\s*\d{3}\s*:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final lower = text.toLowerCase();

    if (lower.contains('cantidad no disponible')) return text;
    if (lower.contains('disponibilidad') && lower.contains('administrador')) {
      return text;
    }
    if (lower.contains('producto seleccionado') &&
        lower.contains('no está disponible')) {
      return text;
    }
    if (lower.contains('precio') && lower.contains('administrador')) {
      return text;
    }

    if (lower.contains('401') ||
        lower.contains('unauthenticated') ||
        lower.contains('no autenticado')) {
      return 'Tu sesión venció. Vuelve a iniciar sesión para continuar.';
    }

    if (lower.contains('403') || lower.contains('forbidden')) {
      return 'No tienes permiso para realizar esta acción.';
    }

    if (lower.contains('timeout') ||
        lower.contains('timed out') ||
        lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('failed host lookup')) {
      return 'No se pudo conectar en este momento. Revisa tu conexión e inténtalo nuevamente.';
    }

    if (text.startsWith('{') || text.startsWith('<!DOCTYPE')) {
      return 'No se pudo completar la operación. Revisa los datos e inténtalo nuevamente.';
    }

    return text.isEmpty
        ? 'No se pudo completar la operación. Inténtalo nuevamente.'
        : text;
  }

  @override
  void onClose() {
    _draftSaveDebounce?.cancel();
    _backgroundLocationSubscription?.cancel();
    _backgroundStatusSubscription?.cancel();
    observacionJornadaController.dispose();
    super.onClose();
  }
}
