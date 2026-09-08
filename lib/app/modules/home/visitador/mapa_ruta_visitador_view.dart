import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../utils/app_theme.dart';
import '../../../utils/safe_ui.dart';
import 'visitador_operativo_controller.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'dart:math' as math;

class MapaRutaVisitadorView extends StatefulWidget {
  const MapaRutaVisitadorView({super.key, this.onOpenHome});

  final VoidCallback? onOpenHome;

  @override
  State<MapaRutaVisitadorView> createState() => _MapaRutaVisitadorViewState();
}

class _MapaRutaVisitadorViewState extends State<MapaRutaVisitadorView> {
  late final VisitadorOperativoController controller;
  final MapController mapController = MapController();

  // Ubicación usada únicamente para mover el marcador del Visitador.
  // No modifica lastPosition y no crea registros de tracking.
  final ValueNotifier<LatLng?> _visualPosition = ValueNotifier<LatLng?>(null);
  StreamSubscription<Position>? _visualPositionSubscription;

  // SIGPRED 10.23.2 · puntero brújula visual
  final ValueNotifier<double> _visualHeading = ValueNotifier<double>(0);
  StreamSubscription<CompassEvent>? _compassSubscription;
  DateTime? _lastCompassHeadingAt;
  static const Duration _compassFreshness = Duration(seconds: 2);

  // SIGPRED 10.23.1 · animación visual GPS local
  Timer? _visualMarkerAnimationTimer;
  static const Duration _visualMarkerFrame = Duration(milliseconds: 80);
  static const int _visualMarkerSteps = 12;

  List<LatLng> _roadRoutePoints = const <LatLng>[];
  bool _loadingRoute = false;
  String _routeStatus = 'Ruta recomendada';
  double? _routeDistanceKm;
  double? _routeDurationMin;
  String _lastSignature = '';
  Map<String, dynamic>? _selectedDetail;

  static const LatLng _defaultCenter = LatLng(-17.3895, -66.1568);

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<VisitadorOperativoController>()
        ? Get.find<VisitadorOperativoController>()
        : Get.put(VisitadorOperativoController());

    _visualPosition.value = _controllerCurrentPosition();
    unawaited(_startVisualLocationStream());
    unawaited(_startVisualHeadingStream());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!controller.tieneRuta && !controller.isLoading.value) {
        await controller.refreshAll();
      }

      if (controller.jornadaActiva && !controller.jornadaPausada.value) {
        await controller.actualizarUbicacionOperativa();
      }

      if (!mounted) return;
      await _loadRoute(force: true);
      _fitAll();
    });
  }

  @override
  void dispose() {
    _visualPositionSubscription?.cancel();
    _compassSubscription?.cancel();
    _visualMarkerAnimationTimer?.cancel();
    _visualPosition.dispose();
    _visualHeading.dispose();
    mapController.dispose();
    super.dispose();
  }

  List<_MapPoint> _points() {
    final rows = <_MapPoint>[];
    final details = controller.detallesRutaOrdenados;

    for (var i = 0; i < details.length; i++) {
      final detail = details[i];
      final client = _map(detail['cliente']) ?? detail;

      final lat = _double(
        client['cliente_lat'] ??
            client['lat'] ??
            client['latitude'] ??
            detail['cliente_lat'] ??
            detail['lat'] ??
            detail['latitude'],
      );
      final lng = _double(
        client['cliente_lng'] ??
            client['lng'] ??
            client['longitude'] ??
            detail['cliente_lng'] ??
            detail['lng'] ??
            detail['longitude'],
      );

      if (!_valid(lat, lng)) continue;

      rows.add(
        _MapPoint(
          index: i + 1,
          detail: detail,
          point: LatLng(lat!, lng!),
          name: controller.clienteNombre(detail),
          address: controller.clienteDireccion(detail),
          visited: controller.detalleVisitado(detail),
          revisitable: controller.detalleRevisitable(detail),
          effective: controller.detalleVisitaEfectiva(detail),
          motivo: controller.detalleMotivoVisita(detail),
          recommended:
              controller.siguienteVisitaSugerida != null &&
              controller.esMismoDetalle(
                detail,
                controller.siguienteVisitaSugerida!,
              ),
          selected:
              _selectedDetail != null &&
              controller.esMismoDetalle(detail, _selectedDetail!),
        ),
      );
    }

    return rows;
  }

  // SIGPRED 10.23.1 · interpolación exclusivamente visual
  void _setVisualPositionSmooth(LatLng target) {
    final from = _visualPosition.value ?? _controllerCurrentPosition();
    _visualMarkerAnimationTimer?.cancel();

    if (from == null) {
      _visualPosition.value = target;
      return;
    }

    final distance = Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      target.latitude,
      target.longitude,
    );

    // No animar ruido GPS mínimo ni saltos grandes/correcciones de señal.
    if (!distance.isFinite || distance < 0.35 || distance > 120) {
      _visualPosition.value = target;
      return;
    }

    var step = 0;
    _visualMarkerAnimationTimer = Timer.periodic(_visualMarkerFrame, (timer) {
      step += 1;
      final rawT = (step / _visualMarkerSteps).clamp(0.0, 1.0);
      // Ease-out suave: la coordenada real sigue siendo el destino final.
      final t = 1 - (1 - rawT) * (1 - rawT);

      _visualPosition.value = LatLng(
        from.latitude + (target.latitude - from.latitude) * t,
        from.longitude + (target.longitude - from.longitude) * t,
      );

      if (step >= _visualMarkerSteps) {
        timer.cancel();
        _visualPosition.value = target;
      }
    });
  }

  LatLng? _controllerCurrentPosition() {
    final p = controller.lastPosition.value;
    if (p == null || !_valid(p.latitude, p.longitude)) return null;
    return LatLng(p.latitude, p.longitude);
  }

  LatLng? _current() {
    return _visualPosition.value ?? _controllerCurrentPosition();
  }

  // SIGPRED 10.23.2 · rumbo visual híbrido brújula/GPS
  double _normalizeHeading(double value) {
    final n = value % 360;
    return n < 0 ? n + 360 : n;
  }

  void _setVisualHeadingSmooth(double target) {
    if (!target.isFinite) return;
    final current = _normalizeHeading(_visualHeading.value);
    final goal = _normalizeHeading(target);
    final delta = ((goal - current + 540) % 360) - 180;
    final factor = delta.abs() >= 70
        ? 0.45
        : delta.abs() >= 25
        ? 0.30
        : 0.20;
    _visualHeading.value = _normalizeHeading(current + delta * factor);
  }

  bool _compassFresh() {
    final last = _lastCompassHeadingAt;
    return last != null && DateTime.now().difference(last) <= _compassFreshness;
  }

  void _applyGpsHeadingFallback(Position position) {
    if (_compassFresh()) return;
    final h = position.heading;
    if (!h.isFinite || h < 0 || h > 360) return;
    if (position.speed.isFinite && position.speed >= 0.6) {
      _setVisualHeadingSmooth(h);
    }
  }

  Future<void> _startVisualHeadingStream() async {
    if (kIsWeb) return;
    try {
      await _compassSubscription?.cancel();
      final events = FlutterCompass.events;
      if (events == null) return;
      _compassSubscription = events.listen(
        (event) {
          final h = event.heading;
          if (!mounted || h == null || !h.isFinite) return;
          _lastCompassHeadingAt = DateTime.now();
          _setVisualHeadingSmooth(h);
        },
        onError: (Object error) {
          debugPrint('Brújula visual no disponible: $error');
        },
      );
    } catch (error) {
      debugPrint('No se pudo iniciar la brújula visual: $error');
    }
  }

  Future<void> _startVisualLocationStream() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }

      await _visualPositionSubscription?.cancel();

      const settings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      );

      _visualPositionSubscription =
          Geolocator.getPositionStream(locationSettings: settings).listen(
            (position) {
              if (!mounted || !_valid(position.latitude, position.longitude)) {
                return;
              }

              // SOLO VISUAL:
              // el servicio background mantiene por separado la persistencia GPS.
              _setVisualPositionSmooth(
                LatLng(position.latitude, position.longitude),
              );
              _applyGpsHeadingFallback(position);
            },
            onError: (Object error) {
              debugPrint('GPS visual del mapa no disponible: $error');
            },
          );
    } catch (error) {
      debugPrint('No se pudo iniciar GPS visual del mapa: $error');
    }
  }

  bool _pointWithinVisitRadius(_MapPoint point) {
    final current = _current();
    if (current == null) {
      return controller.detalleDentroDeRadio(point.detail);
    }

    final distance = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      point.point.latitude,
      point.point.longitude,
    );

    return distance <=
        VisitadorOperativoController.radioHabilitacionVisitaMetros;
  }

  String _visualDistanceLabel(_MapPoint point) {
    final current = _current();
    if (current == null) {
      return controller.distanciaDetalleLabel(point.detail);
    }

    final distance = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      point.point.latitude,
      point.point.longitude,
    );

    if (distance < 1000) return '${distance.round()} m';
    return '${(distance / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _loadRoute({bool force = false}) async {
    final points = _points();
    final current = _current();
    final pending = points.where((p) => !p.visited).toList();

    List<LatLng> waypoints;

    if (_selectedDetail != null) {
      _MapPoint? target;
      for (final p in points) {
        if (controller.esMismoDetalle(p.detail, _selectedDetail!)) {
          target = p;
          break;
        }
      }

      waypoints = [
        if (current != null) current,
        if (target != null) target.point,
      ];
    } else {
      waypoints = [
        if (current != null) current,
        ...pending.take(18).map((p) => p.point),
      ];
    }

    if (waypoints.length < 2) {
      if (!mounted) return;
      setState(() {
        _roadRoutePoints = waypoints;
        _routeDistanceKm = null;
        _routeDurationMin = null;
        _routeStatus = 'Elige un punto para trazar una ruta';
      });
      return;
    }

    final signature = waypoints
        .map(
          (p) =>
              '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}',
        )
        .join(';');

    if (!force && signature == _lastSignature && _roadRoutePoints.length > 1) {
      return;
    }

    if (mounted) {
      setState(() {
        _loadingRoute = true;
        _routeStatus = _selectedDetail == null
            ? 'Calculando ruta recomendada...'
            : 'Calculando ruta al destino...';
      });
    }

    try {
      final result = await _fetchRoadRoute(waypoints);
      if (!mounted) return;
      setState(() {
        _lastSignature = signature;
        _roadRoutePoints = result.points.length > 1 ? result.points : waypoints;
        _routeDistanceKm = result.distanceMeters == null
            ? null
            : result.distanceMeters! / 1000;
        _routeDurationMin = result.durationSeconds == null
            ? null
            : result.durationSeconds! / 60;
        _routeStatus = _selectedDetail == null
            ? 'Ruta recomendada'
            : 'Ruta al destino';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lastSignature = signature;
        _roadRoutePoints = waypoints;
        _routeDistanceKm = null;
        _routeDurationMin = null;
        _routeStatus = 'Ruta directa';
      });
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  Future<_RoadResult> _fetchRoadRoute(List<LatLng> points) async {
    final coordinates = points
        .map(
          (p) =>
              '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}',
        )
        .join(';');

    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '$coordinates?overview=full&geometries=geojson&steps=false',
    );

    final response = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Ruta no disponible');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['routes'] is! List) {
      throw Exception('Respuesta inválida');
    }

    final routes = decoded['routes'] as List;
    if (routes.isEmpty || routes.first is! Map) {
      throw Exception('Sin rutas');
    }

    final route = Map<String, dynamic>.from(routes.first as Map);
    final geometry = route['geometry'];
    final rawCoords = geometry is Map ? geometry['coordinates'] : null;
    final resultPoints = <LatLng>[];

    if (rawCoords is List) {
      for (final item in rawCoords) {
        if (item is List && item.length >= 2) {
          final lng = _double(item[0]);
          final lat = _double(item[1]);
          if (_valid(lat, lng)) {
            resultPoints.add(LatLng(lat!, lng!));
          }
        }
      }
    }

    return _RoadResult(
      points: resultPoints,
      distanceMeters: _double(route['distance']),
      durationSeconds: _double(route['duration']),
    );
  }

  void _fitAll() {
    final points = <LatLng>[
      ..._roadRoutePoints,
      ..._points().map((p) => p.point),
      if (_current() != null) _current()!,
    ];

    if (points.isEmpty) {
      mapController.move(_defaultCenter, 13);
      return;
    }

    if (points.length == 1) {
      mapController.move(points.first, 17);
      return;
    }

    mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.fromLTRB(34, 92, 34, 210),
        maxZoom: 17,
      ),
    );
  }

  Future<void> _myLocation() async {
    await controller.actualizarUbicacionActual();
    if (!mounted) return;

    final controllerPosition = _controllerCurrentPosition();
    if (controllerPosition != null) {
      _visualPosition.value = controllerPosition;
    }

    await _loadRoute(force: true);

    final current = _current();
    if (current != null) {
      mapController.move(current, 17);
    }
  }

  Future<void> _selectPoint(_MapPoint point) async {
    setState(() => _selectedDetail = point.detail);
    await controller.actualizarUbicacionOperativa();
    if (!mounted) return;
    await _loadRoute(force: true);
    mapController.move(point.point, 16.5);
  }

  Future<void> _clearSelection() async {
    setState(() => _selectedDetail = null);
    await _loadRoute(force: true);
    _fitAll();
  }

  Future<void> _openPoint(_MapPoint point) async {
    final distance = _visualDistanceLabel(point);
    final near = _pointWithinVisitRadius(point);
    final paused = controller.jornadaPausada.value;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _PointBadge(point: point),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          point.name,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          point.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _InfoBox(
                      icon: Icons.directions_walk_rounded,
                      label: 'Distancia',
                      value: distance,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InfoBox(
                      icon: point.recommended
                          ? Icons.star_rounded
                          : Icons.place_outlined,
                      label: 'Estado',
                      value: point.visited
                          ? (point.effective ? 'Efectiva' : 'No efectiva')
                          : point.recommended
                          ? 'Recomendada'
                          : point.selected
                          ? 'Destino'
                          : 'Disponible',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (point.visited && !point.revisitable)
                _Notice(
                  icon: Icons.check_circle_rounded,
                  text: point.effective
                      ? 'Esta visita ya fue registrada como efectiva.'
                      : 'Esta visita ya fue registrada.',
                  color: SigmaColors.success,
                )
              else if (point.revisitable && !controller.jornadaActiva)
                _Notice(
                  icon: Icons.refresh_rounded,
                  text:
                      'Visita no efectiva${point.motivo.isNotEmpty ? ' · ${point.motivo}' : ''}. '
                      'Inicia tu jornada para volver a visitarla.',
                  color: SigmaColors.warning,
                )
              else if (point.revisitable && paused)
                _Notice(
                  icon: Icons.pause_circle_outline_rounded,
                  text:
                      'Visita no efectiva${point.motivo.isNotEmpty ? ' · ${point.motivo}' : ''}. '
                      'Reanuda tu jornada para volver a visitarla.',
                  color: SigmaColors.warning,
                )
              else if (point.revisitable) ...[
                _Notice(
                  icon: Icons.refresh_rounded,
                  text:
                      'Último resultado: ${point.motivo.isEmpty ? 'No efectiva' : point.motivo}.',
                  color: SigmaColors.warning,
                ),
                const SizedBox(height: 8),
                if (near)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: SigmaColors.warning,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        final draft = await controller.iniciarORecuperarVisita(
                          point.detail,
                          revisita: true,
                        );
                        if (draft != null) {
                          widget.onOpenHome?.call();
                        }
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Volver a visitar'),
                    ),
                  )
                else
                  const _Notice(
                    icon: Icons.location_searching_rounded,
                    text:
                        'Acércate a 100 m o menos del punto para volver a visitarlo.',
                    color: SigmaColors.warning,
                  ),
              ] else if (!controller.jornadaActiva)
                const _Notice(
                  icon: Icons.play_circle_outline_rounded,
                  text: 'Primero inicia tu jornada desde Inicio.',
                )
              else if (paused)
                const _Notice(
                  icon: Icons.pause_circle_outline_rounded,
                  text: 'Tu jornada está pausada. Reanúdala desde Inicio.',
                  color: SigmaColors.warning,
                )
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await _selectPoint(point);
                    },
                    icon: const Icon(Icons.route_rounded),
                    label: Text(
                      point.selected
                          ? 'Actualizar ruta a este punto'
                          : 'Ir a este punto',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (near)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: SigmaColors.success,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        final draft = await controller.iniciarORecuperarVisita(
                          point.detail,
                        );
                        if (draft != null) {
                          widget.onOpenHome?.call();
                        }
                      },
                      icon: const Icon(Icons.medical_services_outlined),
                      label: const Text('Realizar visita médica'),
                    ),
                  )
                else
                  const _Notice(
                    icon: Icons.location_searching_rounded,
                    text:
                        'La visita se habilita cuando estés a 100 m o menos del punto.',
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final points = _points();
      final current = _current();
      final center =
          current ?? (points.isNotEmpty ? points.first.point : _defaultCenter);

      return Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: points.isNotEmpty ? 15 : 13,
                  minZoom: 3,
                  maxZoom: 22,
                ),
                children: [
                  TileLayer(
                    // flutter_map 8.3.x usa su cache nativo en Android.
                    // Solo se almacenan teselas realmente visualizadas.
                    tileProvider: NetworkTileProvider(),
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.sigpred.app',
                  ),
                  if (_roadRoutePoints.length > 1)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _roadRoutePoints,
                          color: SigmaColors.primary,
                          strokeWidth: 5,
                        ),
                      ],
                    ),
                  if (_selectedDetail != null)
                    CircleLayer(
                      circles: [
                        for (final point in points)
                          if (controller.esMismoDetalle(
                            point.detail,
                            _selectedDetail!,
                          ))
                            CircleMarker(
                              point: point.point,
                              radius: VisitadorOperativoController
                                  .radioHabilitacionVisitaMetros,
                              useRadiusInMeter: true,
                              color: SigmaColors.secondary.withOpacity(0.08),
                              borderColor: SigmaColors.secondary.withOpacity(
                                0.55,
                              ),
                              borderStrokeWidth: 2,
                            ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      for (final point in points)
                        Marker(
                          point: point.point,
                          width: 62,
                          height: 72,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _openPoint(point),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _MapMarker(point: point),
                                const SizedBox(height: 2),
                                _MarkerLabel(point: point),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  ValueListenableBuilder<LatLng?>(
                    valueListenable: _visualPosition,
                    builder: (context, visualPosition, child) {
                      final position = visualPosition ?? current;
                      if (position == null) {
                        return const SizedBox.shrink();
                      }

                      return MarkerLayer(
                        markers: [
                          Marker(
                            point: position,
                            width: 56,
                            height: 56,
                            child: ValueListenableBuilder<double>(
                              valueListenable: _visualHeading,
                              builder: (context, heading, child) {
                                return Transform.rotate(
                                  angle: heading * (math.pi / 180),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: SigmaColors.secondary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: SigmaColors.secondary
                                              .withOpacity(0.24),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.navigation_rounded,
                                      color: Colors.white,
                                      size: 27,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: _TopMapBar(
                  controller: controller,
                  selected: _selectedDetail,
                  loading: _loadingRoute,
                ),
              ),
            ),

            Positioned(
              right: 12,
              top: 118,
              child: Column(
                children: [
                  _FloatingMapButton(
                    tooltip: 'Mi ubicación',
                    icon: Icons.my_location_rounded,
                    onPressed: _myLocation,
                  ),
                  const SizedBox(height: 8),
                  _FloatingMapButton(
                    tooltip: 'Ver toda la ruta',
                    icon: Icons.fit_screen_rounded,
                    onPressed: _fitAll,
                  ),
                  if (_selectedDetail != null) ...[
                    const SizedBox(height: 8),
                    _FloatingMapButton(
                      tooltip: 'Ruta recomendada',
                      icon: Icons.auto_awesome_rounded,
                      onPressed: _clearSelection,
                    ),
                  ],
                ],
              ),
            ),

            if (_loadingRoute)
              const Positioned(
                left: 12,
                right: 12,
                top: 92,
                child: LinearProgressIndicator(),
              ),

            DraggableScrollableSheet(
              initialChildSize: 0.20,
              minChildSize: 0.14,
              maxChildSize: 0.55,
              snap: true,
              snapSizes: const [0.20, 0.55],
              builder: (context, scrollController) {
                return _MapBottomSheet(
                  controller: controller,
                  points: points,
                  selected: _selectedDetail,
                  routeStatus: _routeStatus,
                  distanceKm: _routeDistanceKm,
                  durationMin: _routeDurationMin,
                  scrollController: scrollController,
                  onPointTap: _openPoint,
                  onClearSelection: _clearSelection,
                  onOpenHome: widget.onOpenHome,
                );
              },
            ),
          ],
        ),
      );
    });
  }
}

class _TopMapBar extends StatelessWidget {
  const _TopMapBar({
    required this.controller,
    required this.selected,
    required this.loading,
  });

  final VisitadorOperativoController controller;
  final Map<String, dynamic>? selected;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final paused = controller.jornadaPausada.value;
    final title = selected == null
        ? 'Mi ruta'
        : controller.clienteNombre(selected!);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 3,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Row(
          children: [
            Icon(
              selected == null ? Icons.route_rounded : Icons.navigation_rounded,
              color: SigmaColors.primary,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    paused
                        ? 'Jornada pausada'
                        : loading
                        ? 'Calculando...'
                        : selected == null
                        ? '${controller.visitasPendientes} visita(s) pendiente(s)'
                        : controller.distanciaDetalleLabel(selected!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (selected == null)
              const Icon(
                Icons.auto_awesome_rounded,
                color: SigmaColors.secondary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _MapBottomSheet extends StatelessWidget {
  const _MapBottomSheet({
    required this.controller,
    required this.points,
    required this.selected,
    required this.routeStatus,
    required this.distanceKm,
    required this.durationMin,
    required this.scrollController,
    required this.onPointTap,
    required this.onClearSelection,
    required this.onOpenHome,
  });

  final VisitadorOperativoController controller;
  final List<_MapPoint> points;
  final Map<String, dynamic>? selected;
  final String routeStatus;
  final double? distanceKm;
  final double? durationMin;
  final ScrollController scrollController;
  final Future<void> Function(_MapPoint point) onPointTap;
  final Future<void> Function() onClearSelection;
  final VoidCallback? onOpenHome;

  @override
  Widget build(BuildContext context) {
    final pending = points.where((p) => !p.visited).toList();

    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 10,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: selected == null
                      ? _RecommendationSummary(
                          controller: controller,
                          points: pending,
                          routeStatus: routeStatus,
                          distanceKm: distanceKm,
                          durationMin: durationMin,
                        )
                      : _SelectedSummary(
                          controller: controller,
                          selected: selected!,
                          routeStatus: routeStatus,
                          distanceKm: distanceKm,
                          durationMin: durationMin,
                          onClearSelection: onClearSelection,
                        ),
                ),
              ],
            ),
          ),
          if (!controller.jornadaActiva)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: FilledButton.icon(
                  onPressed: onOpenHome,
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Ir a Inicio'),
                ),
              ),
            )
          else if (controller.jornadaPausada.value)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: const _Notice(
                  icon: Icons.pause_circle_outline_rounded,
                  text: 'La jornada está pausada. Reanúdala desde Inicio.',
                  color: SigmaColors.warning,
                ),
              ),
            )
          else if (pending.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: _Notice(
                  icon: Icons.done_all_rounded,
                  text: 'No quedan visitas pendientes.',
                  color: SigmaColors.success,
                ),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 7),
                child: Text(
                  'Puntos de visita',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: pending.length,
              itemBuilder: (context, index) {
                final p = pending[index];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 7),
                  child: _PointListTile(
                    point: p,
                    distance: controller.distanciaDetalleLabel(p.detail),
                    onTap: () => onPointTap(p),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
          ],
        ],
      ),
    );
  }
}

class _RecommendationSummary extends StatelessWidget {
  const _RecommendationSummary({
    required this.controller,
    required this.points,
    required this.routeStatus,
    required this.distanceKm,
    required this.durationMin,
  });

  final VisitadorOperativoController controller;
  final List<_MapPoint> points;
  final String routeStatus;
  final double? distanceKm;
  final double? durationMin;

  @override
  Widget build(BuildContext context) {
    _MapPoint? recommended;
    for (final p in points) {
      if (p.recommended) {
        recommended = p;
        break;
      }
    }

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: SigmaColors.primary.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: SigmaColors.primary,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recommended == null
                    ? 'Elige una visita'
                    : 'Recomendado: ${recommended.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                recommended == null
                    ? 'Toca un punto en el mapa.'
                    : '${controller.distanciaDetalleLabel(recommended.detail)} · toca cualquier punto si prefieres otro',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (distanceKm != null)
          _RoutePill(text: '${distanceKm!.toStringAsFixed(1)} km'),
      ],
    );
  }
}

class _SelectedSummary extends StatelessWidget {
  const _SelectedSummary({
    required this.controller,
    required this.selected,
    required this.routeStatus,
    required this.distanceKm,
    required this.durationMin,
    required this.onClearSelection,
  });

  final VisitadorOperativoController controller;
  final Map<String, dynamic> selected;
  final String routeStatus;
  final double? distanceKm;
  final double? durationMin;
  final Future<void> Function() onClearSelection;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: SigmaColors.secondary.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.navigation_rounded,
            color: SigmaColors.secondary,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                controller.clienteNombre(selected),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  controller.distanciaDetalleLabel(selected),
                  if (durationMin != null) '${durationMin!.round()} min aprox.',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Volver a recomendada',
          onPressed: onClearSelection,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

class _PointListTile extends StatelessWidget {
  const _PointListTile({
    required this.point,
    required this.distance,
    required this.onTap,
  });

  final _MapPoint point;
  final String distance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              _PointBadge(point: point, compact: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      point.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      point.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                distance,
                style: const TextStyle(
                  color: SigmaColors.secondary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointBadge extends StatelessWidget {
  const _PointBadge({required this.point, this.compact = false});

  final _MapPoint point;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = point.visited && !point.effective
        ? SigmaColors.warning
        : point.visited
        ? SigmaColors.success
        : point.selected
        ? SigmaColors.secondary
        : SigmaColors.primary;

    return Container(
      width: compact ? 38 : 46,
      height: compact ? 38 : 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        shape: BoxShape.circle,
      ),
      child: Icon(
        point.revisitable
            ? Icons.refresh_rounded
            : point.visited && !point.effective
            ? Icons.remove_shopping_cart_outlined
            : point.visited
            ? Icons.check_rounded
            : point.selected
            ? Icons.navigation_rounded
            : point.recommended
            ? Icons.star_rounded
            : Icons.place_outlined,
        color: color,
        size: compact ? 20 : 23,
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.point});
  final _MapPoint point;

  @override
  Widget build(BuildContext context) {
    final fill = point.visited && !point.effective
        ? SigmaColors.warning
        : point.visited
        ? SigmaColors.success
        : point.selected
        ? SigmaColors.secondary
        : point.recommended
        ? SigmaColors.primary
        : Colors.white;
    final foreground =
        point.revisitable ||
            point.visited ||
            point.selected ||
            point.recommended
        ? Colors.white
        : SigmaColors.primary;

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(
          color:
              point.revisitable ||
                  point.visited ||
                  point.selected ||
                  point.recommended
              ? Colors.white
              : SigmaColors.primary,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 10),
        ],
      ),
      child: Icon(
        point.revisitable
            ? Icons.refresh_rounded
            : point.visited && !point.effective
            ? Icons.remove_shopping_cart_outlined
            : point.visited
            ? Icons.check_rounded
            : point.selected
            ? Icons.navigation_rounded
            : point.recommended
            ? Icons.star_rounded
            : Icons.place_rounded,
        color: foreground,
        size: 20,
      ),
    );
  }
}

class _MarkerLabel extends StatelessWidget {
  const _MarkerLabel({required this.point});
  final _MapPoint point;

  @override
  Widget build(BuildContext context) {
    final text = point.revisitable
        ? 'VOLVER'
        : point.visited && !point.effective
        ? 'NO EFECT.'
        : point.visited
        ? 'HECHA'
        : point.selected
        ? 'DESTINO'
        : point.recommended
        ? 'CERCA'
        : '${point.index}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: point.visited && !point.effective
              ? SigmaColors.warning
              : point.visited
              ? SigmaColors.success
              : point.selected
              ? SigmaColors.secondary
              : SigmaColors.primary,
        ),
      ),
    );
  }
}

class _FloatingMapButton extends StatelessWidget {
  const _FloatingMapButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final dynamic onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withOpacity(0.97),
      elevation: 4,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: SigmaColors.primary),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _RoutePill extends StatelessWidget {
  const _RoutePill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: SigmaColors.primary.withOpacity(0.09),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: SigmaColors.primary,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.text,
    this.color = SigmaColors.secondary,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPoint {
  const _MapPoint({
    required this.index,
    required this.detail,
    required this.point,
    required this.name,
    required this.address,
    required this.visited,
    required this.revisitable,
    required this.effective,
    required this.motivo,
    required this.recommended,
    required this.selected,
  });

  final int index;
  final Map<String, dynamic> detail;
  final LatLng point;
  final String name;
  final String address;
  final bool visited;
  final bool revisitable;
  final bool effective;
  final String motivo;
  final bool recommended;
  final bool selected;
}

class _RoadResult {
  const _RoadResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final double? distanceMeters;
  final double? durationSeconds;
}

Map<String, dynamic>? _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

double? _double(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

bool _valid(double? lat, double? lng) {
  if (lat == null || lng == null) return false;
  if (!lat.isFinite || !lng.isFinite) return false;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
  if (lat == 0 && lng == 0) return false;
  return true;
}
