import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/models/location_results.dart';
import '../../../data/models/userlastlocation.dart';
import '../../../data/providers/location_provider.dart';
import '../../../utils/app_theme.dart';
import 'supervisor_mobile_ui.dart';

class SupervisorMobileTrackingView extends StatefulWidget {
  const SupervisorMobileTrackingView({super.key});

  @override
  State<SupervisorMobileTrackingView> createState() =>
      _SupervisorMobileTrackingViewState();
}

class _SupervisorMobileTrackingViewState
    extends State<SupervisorMobileTrackingView> {
  final LocationProvider _locationProvider = Get.find<LocationProvider>();
  final MapController _mapController = MapController();

  final List<Map<String, dynamic>> _users = [];
  final List<UserLastLocation> _lastLocations = [];
  final List<LocationResult> _history = [];
  final List<Map<String, dynamic>> _visits = [];
  final List<_RoutePoint> _routePoints = [];

  Map<String, dynamic>? _assignedRoute;
  DateTime _date = DateTime.now();
  int? _selectedUserId;
  bool _historyMode = true;
  // SIGPRED 10.23.3 R2 · tracking remoto visual fluido Supervisor
  LatLng? _remoteVisualPosition;
  Timer? _remoteVisualTimer;
  int? _remoteVisualUserId;
  bool _loading = true;
  String? _error;
  String _routeName = 'Sin ruta planificada';
  String _zoneName = 'Sin zona informada';

  Timer? _liveTimer;
  bool _mapReady = false;
  bool _liveRefreshInFlight = false;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialLoad());
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _remoteVisualTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    await _loadUsers();
    await _loadData();
    _configureLiveTimer();
  }

  Future<void> _loadUsers() async {
    try {
      final rows = await _locationProvider.getTrackableUsers();
      if (!mounted) return;
      setState(() {
        _users
          ..clear()
          ..addAll(rows);
        if (_selectedUserId == null && _users.isNotEmpty) {
          _selectedUserId = _intOf(_users.first['id']);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _cleanError(e));
    }
  }

  Future<void> _loadData({bool silent = false}) async {
    final requestToken = ++_loadToken;

    if (_selectedUserId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final day = _dateText(_historyMode ? _date : DateTime.now());
      final results = await Future.wait<dynamic>([
        _locationProvider.getLastLocations(),
        _locationProvider.getAssignedRouteForDay(
          userId: _selectedUserId!,
          date: day,
        ),
        _locationProvider.getUserLocations(
          userId: _selectedUserId!,
          perPage: _historyMode ? 1000 : 350,
          from: day,
          to: day,
        ),
        _locationProvider.getVisitsForDay(userId: _selectedUserId!, date: day),
      ]);

      if (!mounted || requestToken != _loadToken) return;

      final lastRows = results[0] as List<UserLastLocation>;
      final route = results[1] as Map<String, dynamic>?;
      final historyRows = (results[2] as dynamic).data as List<LocationResult>;
      final visitRows = List<Map<String, dynamic>>.from(
        results[3] as List<Map<String, dynamic>>,
      );
      final routeData = _buildRouteData(route, visitRows);

      setState(() {
        _lastLocations
          ..clear()
          ..addAll(lastRows);
        _history
          ..clear()
          ..addAll(historyRows);
        _visits
          ..clear()
          ..addAll(visitRows);
        _routePoints
          ..clear()
          ..addAll(routeData.points);
        _assignedRoute = route;
        _routeName = routeData.name;
        _zoneName = routeData.zoneName;
        _error = null;
        if (!silent) _loading = false;
      });

      if (_mapReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_historyPoints.isNotEmpty) {
            _fitRecordedPath();
          } else if (_routePoints.isNotEmpty) {
            _fitVisitPoints();
          } else {
            _centerCurrentVisitor();
          }
        });
      }
    } catch (e) {
      if (!mounted || requestToken != _loadToken) return;
      setState(() {
        _error = _cleanError(e);
        if (!silent) _loading = false;
      });
    }
  }

  void _setRemoteVisualDirect(LatLng target) {
    _remoteVisualTimer?.cancel();
    if (!mounted) return;
    setState(() => _remoteVisualPosition = target);
  }

  void _animateRemoteMarkerTo(LatLng target) {
    if (!mounted) return;

    final from = _remoteVisualPosition;
    _remoteVisualTimer?.cancel();

    if (from == null) {
      _setRemoteVisualDirect(target);
      return;
    }

    final latDelta = (target.latitude - from.latitude).abs();
    final lngDelta = (target.longitude - from.longitude).abs();

    // Un salto mayor a ~1 km se considera anómalo para la animación visual.
    if (latDelta > 0.01 || lngDelta > 0.01) {
      _setRemoteVisualDirect(target);
      return;
    }

    var step = 0;
    const steps = 100;

    _remoteVisualTimer = Timer.periodic(const Duration(milliseconds: 140), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      step++;
      final rawT = (step / steps).clamp(0.0, 1.0).toDouble();
      final smoothT = rawT * rawT * (3.0 - 2.0 * rawT);

      setState(() {
        _remoteVisualPosition = LatLng(
          from.latitude + (target.latitude - from.latitude) * smoothT,
          from.longitude + (target.longitude - from.longitude) * smoothT,
        );
      });

      if (step >= steps) {
        timer.cancel();
        if (mounted) {
          setState(() => _remoteVisualPosition = target);
        }
      }
    });
  }

  void _syncRemoteVisualFromCurrent() {
    if (_historyMode || _selectedUserId == null) return;

    final live = _livePoint;
    final last = _selectedLast;
    final target = live != null
        ? LatLng(live.latitude, live.longitude)
        : last != null && _validCoordinate(last.latitude, last.longitude)
        ? LatLng(last.latitude, last.longitude)
        : null;

    if (target == null) return;

    if (_remoteVisualUserId != _selectedUserId) {
      _remoteVisualUserId = _selectedUserId;
      _setRemoteVisualDirect(target);
      return;
    }

    _animateRemoteMarkerTo(target);
  }

  Future<void> _refreshLive() async {
    if (_historyMode ||
        _selectedUserId == null ||
        !mounted ||
        _liveRefreshInFlight) {
      return;
    }

    _liveRefreshInFlight = true;
    try {
      final day = _dateText(DateTime.now());
      final results = await Future.wait<dynamic>([
        _locationProvider.getLastLocations(),
        _locationProvider.getUserLocations(
          userId: _selectedUserId!,
          perPage: 350,
          from: day,
          to: day,
        ),
        _locationProvider.getVisitsForDay(userId: _selectedUserId!, date: day),
      ]);

      if (!mounted) return;

      final lastRows = results[0] as List<UserLastLocation>;
      final historyRows = (results[1] as dynamic).data as List<LocationResult>;
      final visitRows = List<Map<String, dynamic>>.from(
        results[2] as List<Map<String, dynamic>>,
      );
      final routeData = _buildRouteData(_assignedRoute, visitRows);

      setState(() {
        _lastLocations
          ..clear()
          ..addAll(lastRows);
        _history
          ..clear()
          ..addAll(historyRows);
        _visits
          ..clear()
          ..addAll(visitRows);
        _routePoints
          ..clear()
          ..addAll(routeData.points);
      });
      _syncRemoteVisualFromCurrent();
    } catch (_) {
      // Un corte temporal no debe interrumpir la pantalla de supervisión.
    } finally {
      _liveRefreshInFlight = false;
    }
  }

  void _configureLiveTimer() {
    _liveTimer?.cancel();
    if (!_historyMode) {
      _liveTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _refreshLive(),
      );
    }
  }

  Future<void> _changeMode(bool historyMode) async {
    if (_historyMode == historyMode || _loading) return;
    setState(() {
      _historyMode = historyMode;
      if (!historyMode) {
        _date = DateTime.now();
      }
    });
    _configureLiveTimer();
    await _loadData();
  }

  bool get _canNextHistoryDay {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = DateTime(_date.year, _date.month, _date.day);
    return current.isBefore(today);
  }

  Future<void> _moveHistoryDay(int days) async {
    if (days > 0 && !_canNextHistoryDay) return;
    setState(() => _date = _date.add(Duration(days: days)));
    await _loadData();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
    await _loadData();
  }

  UserLastLocation? get _selectedLast {
    for (final item in _lastLocations) {
      if (item.userId == _selectedUserId) return item;
    }
    return null;
  }

  bool _isDemoTrackingSource(String? source) {
    final value = (source ?? '').trim().toLowerCase();
    return value.startsWith('demo_') || value.contains('demo_street');
  }

  LocationResult? get _livePoint {
    final maxAcceptedTime = DateTime.now().add(const Duration(minutes: 1));
    final candidates = <LocationResult>[];

    for (final item in _history) {
      if (!_validCoordinate(item.latitude, item.longitude) ||
          _isDemoTrackingSource(item.source) ||
          item.capturedAt.toLocal().isAfter(maxAcceptedTime)) {
        continue;
      }
      candidates.add(item);
    }

    final last = _selectedLast;
    if (last != null &&
        _validCoordinate(last.latitude, last.longitude) &&
        !_isDemoTrackingSource(last.source) &&
        !last.updatedAt.toLocal().isAfter(maxAcceptedTime)) {
      candidates.add(
        LocationResult(
          latitude: last.latitude,
          longitude: last.longitude,
          capturedAt: last.updatedAt,
          updatedAt: last.updatedAt,
          accuracy: last.accuracy,
          source: last.source,
        ),
      );
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    return candidates.last;
  }

  bool get _isOnline {
    final point = _livePoint;
    if (point == null) return false;
    final diff = DateTime.now().difference(point.capturedAt.toLocal());
    return !diff.isNegative && diff <= const Duration(minutes: 2);
  }

  String get _selectedName {
    for (final row in _users) {
      if (_intOf(row['id']) == _selectedUserId) {
        return (row['name'] ?? 'Visitador').toString();
      }
    }
    return 'Visitador';
  }

  List<LatLng> get _historyPoints => _history
      .where((item) => _validCoordinate(item.latitude, item.longitude))
      .map((item) => LatLng(item.latitude, item.longitude))
      .toList();

  _TrackingMetrics get _trackingMetrics => _calculateTrackingMetrics(_history);

  int get _completedCount => _routePoints
      .where((point) => point.status == _VisitPointStatus.completed)
      .length;

  int get _ineffectiveCount => _routePoints
      .where((point) => point.status == _VisitPointStatus.ineffective)
      .length;

  int get _pendingCount => _routePoints
      .where((point) => point.status == _VisitPointStatus.pending)
      .length;

  void _onMapReady() {
    if (!mounted) return;
    _mapReady = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_historyPoints.isNotEmpty) {
        _fitRecordedPath();
      } else if (_routePoints.isNotEmpty) {
        _fitVisitPoints();
      } else {
        _centerCurrentVisitor();
      }
    });
  }

  void _fitPoints(
    List<LatLng> points, {
    double singleZoom = 17,
    double maxZoom = 18,
  }) {
    if (!_mapReady || points.isEmpty) return;

    try {
      if (points.length == 1) {
        _mapController.move(points.first, singleZoom);
        return;
      }

      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(44),
          maxZoom: maxZoom,
        ),
      );
    } catch (e) {
      debugPrint('No se pudo ajustar la cámara del mapa: $e');
    }
  }

  void _fitRecordedPath() {
    final points = List<LatLng>.from(_historyPoints);
    if (points.isEmpty) {
      _showMapMessage('No hay recorrido GPS registrado para este día.');
      return;
    }
    _fitPoints(points, singleZoom: 17, maxZoom: 18);
  }

  void _fitVisitPoints() {
    final points = _routePoints
        .map((point) => point.position)
        .toList(growable: false);
    if (points.isEmpty) {
      _showMapMessage('No hay puntos de visita asignados para esta fecha.');
      return;
    }
    _fitPoints(points, singleZoom: 17.5, maxZoom: 17.5);
  }

  void _centerCurrentVisitor() {
    if (!_mapReady) return;

    final live = _livePoint;
    final last = _selectedLast;
    LatLng? target;

    if (live != null) {
      target = LatLng(live.latitude, live.longitude);
    } else if (last != null &&
        _validCoordinate(last.latitude, last.longitude)) {
      target = LatLng(last.latitude, last.longitude);
    }

    if (target == null) {
      _showMapMessage('Todavía no existe una ubicación reciente.');
      return;
    }

    try {
      _mapController.move(target, 17.5);
    } catch (e) {
      debugPrint('No se pudo centrar al visitador: $e');
    }
  }

  void _focusRoutePoint(_RoutePoint point) {
    if (!_mapReady) {
      _showMapMessage('El mapa todavía se está preparando.');
      return;
    }

    try {
      _mapController.move(point.position, 18);
    } catch (e) {
      debugPrint('No se pudo ubicar el punto ${point.order}: $e');
    }
  }

  void _showMapMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: SupervisorEmptyState(
          icon: Icons.group_off_outlined,
          title: 'Sin visitadores asignados',
          message:
              'Cuando exista una asignación de equipo podrás supervisarla desde este mapa.',
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned.fill(child: _mapSurface(context)),
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: _mapFiltersOverlay(context),
            ),
            Positioned(right: 10, bottom: 156, child: _mapActions(context)),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: _mapSummaryCard(context),
            ),
            if (_loading)
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (_error != null)
              Positioned(
                left: 10,
                right: 10,
                top: _historyMode ? 166 : 116,
                child: _MapErrorBanner(
                  message: _error!,
                  onRetry: () => _loadData(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _mapSurface(BuildContext context) {
    final historyPoints = _historyPoints;
    final live = _livePoint;
    final last = _selectedLast;

    LatLng? center;

    if (_historyMode) {
      if (historyPoints.isNotEmpty) {
        center = historyPoints.last;
      } else if (_routePoints.isNotEmpty) {
        center = _routePoints.first.position;
      } else if (last != null &&
          _validCoordinate(last.latitude, last.longitude)) {
        center = LatLng(last.latitude, last.longitude);
      }
    } else {
      if (live != null) {
        center = LatLng(live.latitude, live.longitude);
      } else if (last != null &&
          _validCoordinate(last.latitude, last.longitude)) {
        center = LatLng(last.latitude, last.longitude);
      } else if (_routePoints.isNotEmpty) {
        center = _routePoints.first.position;
      }
    }

    if (center == null) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 44, color: SigmaColors.muted),
            SizedBox(height: 8),
            Text(
              'Sin ubicación para mostrar',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
    }

    final mapChildren = <Widget>[
      TileLayer(
        tileProvider: CancellableNetworkTileProvider(),
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.sigpred.app',
      ),
      if (historyPoints.length > 1)
        PolylineLayer(
          polylines: [
            Polyline(
              points: historyPoints,
              color: Colors.white,
              strokeWidth: _historyMode ? 7 : 5,
            ),
            Polyline(
              points: historyPoints,
              color: SigmaColors.primary.withOpacity(_historyMode ? .92 : .68),
              strokeWidth: _historyMode ? 3.8 : 3,
            ),
          ],
        ),
      MarkerLayer(markers: _routeMarkers()),
      if (_historyMode && historyPoints.isNotEmpty)
        MarkerLayer(markers: _historyMarkers(historyPoints)),
    ];

    if (!_historyMode) {
      final realCurrent = live != null
          ? LatLng(live.latitude, live.longitude)
          : last != null && _validCoordinate(last.latitude, last.longitude)
          ? LatLng(last.latitude, last.longitude)
          : null;
      final current = _remoteVisualPosition ?? realCurrent;

      if (current != null) {
        mapChildren.add(
          MarkerLayer(
            markers: [
              Marker(
                point: current,
                width: 46,
                height: 46,
                child: Container(
                  decoration: BoxDecoration(
                    color: _isOnline ? SigmaColors.success : SigmaColors.muted,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.16),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_pin_circle_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: _historyMode ? 15.5 : 17,
        minZoom: 4,
        maxZoom: 21,
        onMapReady: _onMapReady,
      ),
      children: mapChildren,
    );
  }

  Widget _mapFiltersOverlay(BuildContext context) {
    return Material(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(.12),
      borderRadius: BorderRadius.circular(16),
      color: Theme.of(context).colorScheme.surface.withOpacity(.97),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _ModeChip(
                  selected: _historyMode,
                  icon: Icons.history_rounded,
                  label: 'Historial',
                  onTap: _loading ? null : () => _changeMode(true),
                ),
                const SizedBox(width: 6),
                _ModeChip(
                  selected: !_historyMode,
                  icon: Icons.wifi_tethering_rounded,
                  label: 'En vivo',
                  onTap: _loading ? null : () => _changeMode(false),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedUserId,
                      isExpanded: true,
                      isDense: true,
                      icon: const Icon(Icons.expand_more_rounded),
                      items: _users.map((row) {
                        final id = _intOf(row['id']) ?? 0;
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(
                            (row['name'] ?? 'Visitador $id').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: _loading
                          ? null
                          : (value) async {
                              if (value == null) return;
                              setState(() => _selectedUserId = value);
                              await _loadData();
                            },
                    ),
                  ),
                ),
              ],
            ),
            if (_historyMode) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _MapIconControl(
                    tooltip: 'Día anterior',
                    icon: Icons.chevron_left_rounded,
                    onTap: () => _moveHistoryDay(-1),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Material(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest.withOpacity(.55),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.calendar_month_outlined,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('dd/MM/yyyy').format(_date),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _MapIconControl(
                    tooltip: 'Día siguiente',
                    icon: Icons.chevron_right_rounded,
                    onTap: _canNextHistoryDay ? () => _moveHistoryDay(1) : null,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mapActions(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_historyPoints.isNotEmpty)
          _FloatingMapButton(
            tooltip: 'Ver recorrido GPS',
            icon: Icons.timeline_rounded,
            onTap: _fitRecordedPath,
          ),
        if (_historyPoints.isNotEmpty && _routePoints.isNotEmpty)
          const SizedBox(height: 8),
        if (_routePoints.isNotEmpty)
          _FloatingMapButton(
            tooltip: 'Ver puntos de visita',
            icon: Icons.place_outlined,
            onTap: _fitVisitPoints,
          ),
        if (!_historyMode) ...[
          const SizedBox(height: 8),
          _FloatingMapButton(
            tooltip: 'Centrar visitador',
            icon: Icons.my_location_rounded,
            primary: true,
            onTap: _centerCurrentVisitor,
          ),
        ],
      ],
    );
  }

  Widget _mapSummaryCard(BuildContext context) {
    final online = _isOnline;
    final metrics = _trackingMetrics;

    return Material(
      elevation: 5,
      shadowColor: Colors.black.withOpacity(.14),
      borderRadius: BorderRadius.circular(18),
      color: Theme.of(context).colorScheme.surface.withOpacity(.98),
      child: InkWell(
        onTap: _showRouteOverview,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 11, 11, 11),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (online ? SigmaColors.success : SigmaColors.muted)
                          .withOpacity(.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      online
                          ? Icons.wifi_tethering_rounded
                          : Icons.location_history_rounded,
                      color: online ? SigmaColors.success : SigmaColors.muted,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          '$_routeName · $_zoneName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: SigmaColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: _SummaryValue(
                      color: SigmaColors.success,
                      value: '$_completedCount',
                      label: 'Con pedido',
                    ),
                  ),
                  Expanded(
                    child: _SummaryValue(
                      color: SigmaColors.danger,
                      value: '$_ineffectiveCount',
                      label: 'Sin pedido',
                    ),
                  ),
                  Expanded(
                    child: _SummaryValue(
                      color: SigmaColors.warning,
                      value: '$_pendingCount',
                      label: 'Pendientes',
                    ),
                  ),
                  if (_historyMode)
                    Expanded(
                      child: _SummaryValue(
                        color: SigmaColors.secondary,
                        value: _distanceText(metrics.distanceMeters),
                        label: 'Recorrido',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRouteOverview() async {
    final first = _history.isEmpty ? null : _history.first;
    final last = _history.isEmpty ? null : _history.last;
    final metrics = _trackingMetrics;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: .58,
            minChildSize: .35,
            maxChildSize: .88,
            builder: (context, scrollController) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  Text(
                    _routeName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_selectedName · $_zoneName',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      SupervisorStatusPill(
                        label: '$_completedCount con pedido',
                        color: SigmaColors.success,
                        icon: Icons.check_circle_outline_rounded,
                      ),
                      SupervisorStatusPill(
                        label: '$_ineffectiveCount sin pedido',
                        color: SigmaColors.danger,
                        icon: Icons.remove_shopping_cart_outlined,
                      ),
                      SupervisorStatusPill(
                        label: '$_pendingCount pendientes',
                        color: SigmaColors.warning,
                        icon: Icons.schedule_rounded,
                      ),
                    ],
                  ),
                  if (_historyMode && _history.isNotEmpty) ...[
                    const SizedBox(height: 13),
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest.withOpacity(.45),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SheetMetric(
                              label: 'Distancia',
                              value: _distanceText(metrics.distanceMeters),
                            ),
                          ),
                          Expanded(
                            child: _SheetMetric(
                              label: 'Tiempo activo est.',
                              value: _durationText(metrics.activeDuration),
                            ),
                          ),
                          Expanded(
                            child: _SheetMetric(
                              label: 'GPS',
                              value: '${_history.length}',
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (first != null && last != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _SheetLocationAction(
                              color: const Color(0xFF0EA5E9),
                              icon: Icons.play_arrow_rounded,
                              title: 'Inicio',
                              subtitle: DateFormat(
                                'HH:mm:ss',
                              ).format(first.capturedAt.toLocal()),
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                Future<void>.delayed(
                                  const Duration(milliseconds: 240),
                                  () {
                                    if (!mounted || !_mapReady) return;
                                    _mapController.move(
                                      LatLng(first.latitude, first.longitude),
                                      17.5,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SheetLocationAction(
                              color: const Color(0xFF7C3AED),
                              icon: Icons.flag_rounded,
                              title: 'Fin',
                              subtitle: DateFormat(
                                'HH:mm:ss',
                              ).format(last.capturedAt.toLocal()),
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                Future<void>.delayed(
                                  const Duration(milliseconds: 240),
                                  () {
                                    if (!mounted || !_mapReady) return;
                                    _mapController.move(
                                      LatLng(last.latitude, last.longitude),
                                      17.5,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                  const SizedBox(height: 14),
                  Text(
                    'Puntos de visita',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  if (_routePoints.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        'No hay puntos asignados para esta fecha.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ..._routePoints.map((point) {
                      final visual = _pointVisual(point.status);
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 17,
                          backgroundColor: visual.color.withOpacity(.11),
                          foregroundColor: visual.color,
                          child: Text(
                            '${point.order}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        title: Text(
                          point.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(visual.label),
                        trailing: Icon(
                          Icons.my_location_rounded,
                          color: visual.color,
                          size: 18,
                        ),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          Future<void>.delayed(
                            const Duration(milliseconds: 240),
                            () {
                              if (!mounted) return;
                              _focusRoutePoint(point);
                            },
                          );
                        },
                      );
                    }),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _filtersCard(BuildContext context) {
    return SigmaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: true,
                icon: Icon(Icons.history_rounded),
                label: Text('Historial'),
              ),
              ButtonSegment<bool>(
                value: false,
                icon: Icon(Icons.wifi_tethering_rounded),
                label: Text('En vivo'),
              ),
            ],
            selected: {_historyMode},
            onSelectionChanged: _loading
                ? null
                : (values) => _changeMode(values.first),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _selectedUserId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Visitador médico',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            items: _users.map((row) {
              final id = _intOf(row['id']) ?? 0;
              return DropdownMenuItem<int>(
                value: id,
                child: Text(
                  (row['name'] ?? 'Visitador $id').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: _loading
                ? null
                : (value) async {
                    if (value == null) return;
                    setState(() => _selectedUserId = value);
                    await _loadData();
                  },
          ),
          if (_historyMode) ...[
            const SizedBox(height: 10),
            SupervisorDateNavigator(
              date: _date,
              onPrevious: () => _moveHistoryDay(-1),
              onNext: _canNextHistoryDay ? () => _moveHistoryDay(1) : null,
              onPick: _pickDate,
              label: 'Fecha del recorrido',
              compact: true,
            ),
          ] else ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SigmaColors.success.withOpacity(.06),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.autorenew_rounded,
                    size: 18,
                    color: SigmaColors.success,
                  ),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'El seguimiento se actualiza cada 15 segundos mientras el visitador esté online.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _selectedStatusCard(BuildContext context) {
    final last = _selectedLast;
    final point = _livePoint;
    final online = _isOnline;
    final color = online ? SigmaColors.success : SigmaColors.muted;
    final lastTime = point?.capturedAt ?? last?.updatedAt;

    return SigmaCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  online
                      ? Icons.wifi_tethering_rounded
                      : Icons.wifi_off_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedName,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      online
                          ? 'Online · GPS reciente'
                          : last == null
                          ? 'Sin GPS registrado'
                          : 'Offline · última ubicación histórica',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              SupervisorStatusPill(
                label: online
                    ? 'ONLINE'
                    : last == null
                    ? 'SIN GPS'
                    : 'OFFLINE',
                color: color,
                icon: online ? Icons.circle : Icons.circle_outlined,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CompactInfo(
                  label: 'Zona',
                  value: _zoneName,
                  icon: Icons.map_outlined,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _CompactInfo(
                  label: 'Ruta',
                  value: _routeName,
                  icon: Icons.alt_route_rounded,
                ),
              ),
            ],
          ),
          if (lastTime != null) ...[
            const SizedBox(height: 7),
            _CompactInfo(
              label: 'Último GPS',
              value: DateFormat('dd/MM HH:mm:ss').format(lastTime.toLocal()),
              icon: Icons.schedule_rounded,
              fullWidth: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _historyMapCard(BuildContext context) {
    final points = _historyPoints;
    if (points.isEmpty && _routePoints.isEmpty) {
      return const SupervisorEmptyState(
        icon: Icons.map_outlined,
        title: 'Sin recorrido para esta fecha',
        message:
            'Selecciona otra fecha o verifica que el visitador haya iniciado seguimiento GPS.',
      );
    }

    final initial = points.isNotEmpty
        ? points.last
        : _routePoints.first.position;

    return _MobileMapShell(
      title: 'Recorrido registrado',
      subtitle: '${_history.length} GPS · $_routeName · $_zoneName',
      actionLabel: 'Ver recorrido',
      onAction: _fitRecordedPath,
      legend: const [
        _MapLegend(color: Color(0xFF0EA5E9), label: 'Inicio'),
        _MapLegend(color: Color(0xFF7C3AED), label: 'Fin'),
        _MapLegend(color: SigmaColors.success, label: 'Con pedido'),
        _MapLegend(color: SigmaColors.danger, label: 'Sin pedido'),
        _MapLegend(color: SigmaColors.warning, label: 'Pendiente'),
      ],
      map: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: initial,
          initialZoom: 15.5,
          maxZoom: 21,
          onMapReady: _onMapReady,
        ),
        children: [
          TileLayer(
            tileProvider: CancellableNetworkTileProvider(),
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.sigpred.app',
          ),
          if (points.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(points: points, color: Colors.white, strokeWidth: 8),
                Polyline(
                  points: points,
                  color: SigmaColors.primary,
                  strokeWidth: 4.2,
                ),
              ],
            ),
          MarkerLayer(markers: _routeMarkers()),
          if (points.isNotEmpty) MarkerLayer(markers: _historyMarkers(points)),
        ],
      ),
    );
  }

  Widget _liveMapCard(BuildContext context) {
    final livePoint = _livePoint!;
    final realCurrent = LatLng(livePoint.latitude, livePoint.longitude);
    final current = _remoteVisualPosition ?? realCurrent;

    return _MobileMapShell(
      title: 'Ubicación en vivo',
      subtitle: 'Último GPS real recibido · actualización automática',
      actionLabel: 'Centrar visitador',
      onAction: () {
        if (_mapReady) _mapController.move(current, 17.5);
      },
      trailing: const SupervisorStatusPill(
        label: 'EN VIVO',
        color: SigmaColors.success,
        icon: Icons.wifi_tethering_rounded,
      ),
      legend: const [
        _MapLegend(color: SigmaColors.success, label: 'Visitador'),
        _MapLegend(color: SigmaColors.success, label: 'Con pedido'),
        _MapLegend(color: SigmaColors.danger, label: 'Sin pedido'),
        _MapLegend(color: SigmaColors.warning, label: 'Pendiente'),
      ],
      map: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: current,
          initialZoom: 17,
          maxZoom: 21,
          onMapReady: _onMapReady,
        ),
        children: [
          TileLayer(
            tileProvider: CancellableNetworkTileProvider(),
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.sigpred.app',
          ),
          if (_historyPoints.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _historyPoints,
                  color: SigmaColors.primary.withOpacity(.65),
                  strokeWidth: 3.5,
                ),
              ],
            ),
          MarkerLayer(markers: _routeMarkers()),
          MarkerLayer(
            markers: [
              Marker(
                point: current,
                width: 52,
                height: 52,
                child: Container(
                  decoration: BoxDecoration(
                    color: SigmaColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: SigmaColors.success.withOpacity(.28),
                        blurRadius: 14,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_pin_circle_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _offlineLiveCard(BuildContext context) {
    final last = _selectedLast;
    return SigmaCard(
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: SigmaColors.muted.withOpacity(.09),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_disabled_rounded,
              size: 29,
              color: SigmaColors.muted,
            ),
          ),
          const SizedBox(height: 11),
          const Text(
            'Seguimiento en vivo no disponible',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 5),
          Text(
            last == null
                ? 'Este visitador todavía no tiene una ubicación registrada.'
                : 'El último GPS ya no es reciente. Consulta el historial para revisar su recorrido registrado.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(height: 1.35),
          ),
          if (last != null) ...[
            const SizedBox(height: 10),
            SupervisorStatusPill(
              label:
                  'Último GPS ${DateFormat('dd/MM HH:mm').format(last.updatedAt.toLocal())}',
              color: SigmaColors.muted,
              icon: Icons.history_rounded,
            ),
          ],
          const SizedBox(height: 13),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
            onPressed: () => _changeMode(true),
            icon: const Icon(Icons.history_rounded),
            label: const Text('Ver historial'),
          ),
        ],
      ),
    );
  }

  Widget _historyMetrics(BuildContext context) {
    final metrics = _trackingMetrics;
    return SigmaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SupervisorSectionHeader(
            title: 'Resumen del recorrido',
            subtitle:
                'Tiempo y distancia estimados con tramos GPS continuos; los cortes largos se excluyen.',
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: width,
                    child: SupervisorStatTile(
                      icon: Icons.gps_fixed_rounded,
                      label: 'Puntos GPS',
                      value: '${_history.length}',
                      color: SigmaColors.primary,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: SupervisorStatTile(
                      icon: Icons.straighten_rounded,
                      label: 'Distancia',
                      value: _distanceText(metrics.distanceMeters),
                      color: SigmaColors.secondary,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: SupervisorStatTile(
                      icon: Icons.timelapse_rounded,
                      label: 'Tiempo activo est.',
                      value: _durationText(metrics.activeDuration),
                      color: SigmaColors.success,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: SupervisorStatTile(
                      icon: Icons.pause_circle_outline_rounded,
                      label: 'Cortes GPS',
                      value: '${metrics.pausedGaps}',
                      color: SigmaColors.warning,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _routeProgressCard(BuildContext context) {
    return SigmaCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(14, 5, 10, 5),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: const Text(
          'Puntos de visita asignados',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '$_completedCount con pedido · $_ineffectiveCount sin pedido · $_pendingCount pendientes',
        ),
        leading: const Icon(Icons.flag_outlined, color: SigmaColors.primary),
        children: [
          const Divider(height: 1),
          if (_routePoints.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('No hay puntos de visita asignados para esta fecha.'),
            )
          else
            ..._routePoints.map((point) => _routePointRow(context, point)),
        ],
      ),
    );
  }

  Widget _routePointRow(BuildContext context, _RoutePoint point) {
    final visual = _pointVisual(point.status);
    String detail;
    switch (point.status) {
      case _VisitPointStatus.completed:
        detail = point.visitTime == null
            ? 'Realizada · con pedido'
            : 'Realizada ${DateFormat('HH:mm').format(point.visitTime!.toLocal())} · con pedido';
        break;
      case _VisitPointStatus.ineffective:
        detail = point.visitTime == null
            ? 'No efectiva · sin pedido'
            : 'No efectiva ${DateFormat('HH:mm').format(point.visitTime!.toLocal())} · sin pedido';
        break;
      case _VisitPointStatus.pending:
        detail = point.plannedTime?.isNotEmpty == true
            ? 'Pendiente · planificada ${point.plannedTime}'
            : 'Pendiente · sin visita registrada';
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _focusRoutePoint(point);
          _showRoutePointDetail(context, point);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFF0F2F6))),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: visual.color.withOpacity(.11),
                  shape: BoxShape.circle,
                  border: Border.all(color: visual.color.withOpacity(.22)),
                ),
                child: Text(
                  '${point.order}',
                  style: TextStyle(
                    color: visual.color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 9),
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
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: point.status == _VisitPointStatus.pending
                            ? null
                            : visual.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Icon(Icons.my_location_rounded, size: 18, color: visual.color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyEndpoints(BuildContext context) {
    final sorted = [..._history]
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    final first = sorted.first;
    final last = sorted.last;

    return SigmaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SupervisorSectionHeader(
            title: 'Inicio y fin',
            subtitle: 'Los puntos intermedios forman la línea del recorrido.',
            icon: Icons.alt_route_rounded,
          ),
          const SizedBox(height: 10),
          _EndpointRow(
            color: const Color(0xFF0EA5E9),
            title: 'Inicio',
            time: DateFormat('HH:mm:ss').format(first.capturedAt.toLocal()),
            accuracy: first.accuracy,
            onTap: () {
              if (_mapReady) {
                _mapController.move(
                  LatLng(first.latitude, first.longitude),
                  17.5,
                );
              }
            },
          ),
          const SizedBox(height: 7),
          _EndpointRow(
            color: const Color(0xFF7C3AED),
            title: 'Fin / última ubicación',
            time: DateFormat('HH:mm:ss').format(last.capturedAt.toLocal()),
            accuracy: last.accuracy,
            onTap: () {
              if (_mapReady) {
                _mapController.move(
                  LatLng(last.latitude, last.longitude),
                  17.5,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  List<Marker> _routeMarkers() {
    return _routePoints.map((point) {
      final visual = _pointVisual(point.status);
      return Marker(
        point: point.position,
        width: 48,
        height: 48,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showRoutePointDetail(context, point),
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: visual.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.15),
                    blurRadius: 7,
                  ),
                ],
              ),
              child: Text(
                '${point.order}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _historyMarkers(List<LatLng> points) {
    if (points.isEmpty) return [];
    final markers = <Marker>[
      Marker(
        point: points.first,
        width: 40,
        height: 40,
        child: const _EndpointMarker(
          icon: Icons.play_arrow_rounded,
          color: Color(0xFF0EA5E9),
        ),
      ),
    ];

    if (points.length > 1) {
      markers.add(
        Marker(
          point: points.last,
          width: 40,
          height: 40,
          child: const _EndpointMarker(
            icon: Icons.flag_rounded,
            color: Color(0xFF7C3AED),
          ),
        ),
      );
    }
    return markers;
  }

  void _showRoutePointDetail(BuildContext context, _RoutePoint point) {
    final visual = _pointVisual(point.status);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${point.order}. ${point.name}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 7),
                SupervisorStatusPill(
                  label: visual.label,
                  color: visual.color,
                  icon: visual.icon,
                ),
                const SizedBox(height: 15),
                if (point.plannedTime?.isNotEmpty == true)
                  _DetailLine(
                    icon: Icons.schedule_outlined,
                    label: 'Hora planificada',
                    value: point.plannedTime!,
                  ),
                if (point.visitTime != null)
                  _DetailLine(
                    icon: Icons.fact_check_outlined,
                    label: 'Visita registrada',
                    value: DateFormat(
                      'dd/MM/yyyy HH:mm',
                    ).format(point.visitTime!.toLocal()),
                  ),
                if (point.result?.isNotEmpty == true)
                  _DetailLine(
                    icon: Icons.assignment_turned_in_outlined,
                    label: 'Resultado',
                    value: point.result!,
                  ),
                if (point.orderAmount != null)
                  _DetailLine(
                    icon: Icons.payments_outlined,
                    label: 'Pedido / venta',
                    value: 'Bs ${_money(point.orderAmount)}',
                  ),
                if (point.address?.isNotEmpty == true)
                  _DetailLine(
                    icon: Icons.location_on_outlined,
                    label: 'Dirección',
                    value: point.address!,
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Future<void>.delayed(
                        const Duration(milliseconds: 240),
                        () {
                          if (!mounted) return;
                          _focusRoutePoint(point);
                        },
                      );
                    },
                    icon: const Icon(Icons.my_location_rounded),
                    label: const Text('Ubicar en el mapa'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _RouteData _buildRouteData(
    Map<String, dynamic>? route,
    List<Map<String, dynamic>> visits,
  ) {
    if (route == null) {
      return const _RouteData(
        name: 'Sin ruta planificada',
        zoneName: 'Sin zona informada',
        points: [],
      );
    }

    final latestByClient = <int, Map<String, dynamic>>{};
    for (final visit in visits) {
      final clientId = _visitClientId(visit);
      if (clientId == null) continue;
      final previous = latestByClient[clientId];
      if (previous == null ||
          _visitDateTime(visit).isAfter(_visitDateTime(previous))) {
        latestByClient[clientId] = visit;
      }
    }

    final rawDetails = route['detalles'] is List
        ? route['detalles'] as List
        : <dynamic>[];
    final points = <_RoutePoint>[];

    for (var i = 0; i < rawDetails.length; i++) {
      final detail = _mapOf(rawDetails[i]);
      final client = _mapOf(detail['cliente']);
      final lat = _doubleOf(
        client['cliente_lat'] ?? client['latitude'] ?? client['lat'],
      );
      final lng = _doubleOf(
        client['cliente_lng'] ?? client['longitude'] ?? client['lng'],
      );
      if (lat == null || lng == null || !_validCoordinate(lat, lng)) continue;

      final clientId =
          _intOf(detail['cliente_id']) ??
          _intOf(client['cliente_id']) ??
          _intOf(client['id']);
      final visit = clientId == null ? null : latestByClient[clientId];

      _VisitPointStatus status = _VisitPointStatus.pending;
      DateTime? visitTime;
      String? result;
      double? amount;

      if (visit != null) {
        final order = _mapOf(visit['pedido']);
        status = order.isNotEmpty
            ? _VisitPointStatus.completed
            : _VisitPointStatus.ineffective;
        visitTime = _visitDateTimeOrNull(visit);
        result = _nonEmptyText(visit['resultado'] ?? visit['motivo']);
        amount = _doubleOf(
          order['monto_total'] ?? order['ped_monto_total'] ?? order['total'],
        );
      }

      points.add(
        _RoutePoint(
          order: _intOf(detail['orden_visita']) ?? (i + 1),
          name:
              (client['cliente_nombre'] ?? client['name'] ?? 'Punto de visita')
                  .toString(),
          position: LatLng(lat, lng),
          clientId: clientId,
          plannedTime: _nonEmptyText(detail['hora_planificada']),
          status: status,
          visitTime: visitTime,
          result: result,
          orderAmount: amount,
          address: _nonEmptyText(client['cliente_dir']),
        ),
      );
    }

    points.sort((a, b) => a.order.compareTo(b.order));

    final zone = _mapOf(route['zona']);
    final zoneName =
        _nonEmptyText(
          zone['zona_nombre'] ?? route['zona_nombre'] ?? route['zon_nombre'],
        ) ??
        'Sin zona informada';

    return _RouteData(
      name: (route['ruta_nombre'] ?? 'Ruta del día').toString(),
      zoneName: zoneName,
      points: points,
    );
  }

  int? _visitClientId(Map<String, dynamic> visit) {
    final client = _mapOf(visit['cliente']);
    return _intOf(
      client['cliente_id'] ??
          client['id'] ??
          visit['cliente_id'] ??
          visit['cli_id'] ??
          visit['vis_cliente_id'],
    );
  }

  DateTime _visitDateTime(Map<String, dynamic> visit) =>
      _visitDateTimeOrNull(visit) ?? DateTime.fromMillisecondsSinceEpoch(0);

  DateTime? _visitDateTimeOrNull(Map<String, dynamic> visit) {
    final raw =
        visit['fecha_inicio'] ??
        visit['vis_fecha_inicio'] ??
        visit['created_at'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString().replaceFirst(' ', 'T'));
  }

  _TrackingMetrics _calculateTrackingMetrics(List<LocationResult> items) {
    if (items.length < 2) {
      return const _TrackingMetrics(
        activeDuration: Duration.zero,
        distanceMeters: 0,
        pausedGaps: 0,
      );
    }

    final ordered = [...items]
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    var duration = Duration.zero;
    var distance = 0.0;
    var gaps = 0;

    for (var i = 1; i < ordered.length; i++) {
      final previous = ordered[i - 1];
      final current = ordered[i];
      final gap = current.capturedAt.difference(previous.capturedAt);
      if (gap <= Duration.zero) continue;
      if (gap > const Duration(minutes: 2)) {
        gaps++;
        continue;
      }

      final segment = _haversine(
        previous.latitude,
        previous.longitude,
        current.latitude,
        current.longitude,
      );
      final hours = gap.inMilliseconds / 3600000.0;
      final speed = hours <= 0 ? 0 : (segment / 1000) / hours;
      if (speed > 160) continue;

      duration += gap;
      distance += segment;
    }

    return _TrackingMetrics(
      activeDuration: duration,
      distanceMeters: distance,
      pausedGaps: gaps,
    );
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const radius = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double value) => value * math.pi / 180;
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? SigmaColors.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Material(
      color: selected
          ? SigmaColors.primary.withOpacity(.10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
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

class _MapIconControl extends StatelessWidget {
  const _MapIconControl({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton.filledTonal(
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
        icon: Icon(icon),
      ),
    );
  }
}

class _FloatingMapButton extends StatelessWidget {
  const _FloatingMapButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(.18),
      shape: const CircleBorder(),
      color: primary
          ? SigmaColors.primary
          : Theme.of(context).colorScheme.surface,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(
          icon,
          color: primary
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.color,
    required this.value,
    required this.label,
  });

  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9),
        ),
      ],
    );
  }
}

class _SheetMetric extends StatelessWidget {
  const _SheetMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _SheetLocationAction extends StatelessWidget {
  const _SheetLocationAction({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(.07),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapErrorBanner extends StatelessWidget {
  const _MapErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onRetry,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 17,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.refresh_rounded,
                size: 17,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileMapShell extends StatelessWidget {
  const _MobileMapShell({
    required this.title,
    required this.subtitle,
    required this.map,
    required this.actionLabel,
    required this.onAction,
    required this.legend,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget map;
  final String actionLabel;
  final VoidCallback onAction;
  final List<Widget> legend;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SigmaCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            SizedBox(
              height: 520,
              child: Stack(
                children: [
                  Positioned.fill(child: map),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 42),
                      ),
                      onPressed: onAction,
                      icon: const Icon(
                        Icons.center_focus_strong_rounded,
                        size: 17,
                      ),
                      label: Text(actionLabel),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Wrap(spacing: 9, runSpacing: 7, children: legend),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _EndpointMarker extends StatelessWidget {
  const _EndpointMarker({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.16), blurRadius: 7),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

class _CompactInfo extends StatelessWidget {
  const _CompactInfo({
    required this.label,
    required this.value,
    required this.icon,
    this.fullWidth = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(.2),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: SigmaColors.primary),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                Text(
                  value,
                  maxLines: fullWidth ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({
    required this.color,
    required this.title,
    required this.time,
    required this.accuracy,
    required this.onTap,
  });

  final Color color;
  final String title;
  final String time;
  final double? accuracy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(.055),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.my_location_rounded, size: 18, color: color),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '$time · precisión ${accuracy?.toStringAsFixed(1) ?? '—'} m',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: SigmaColors.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _VisitPointStatus { pending, completed, ineffective }

class _PointVisual {
  const _PointVisual(this.color, this.label, this.icon);
  final Color color;
  final String label;
  final IconData icon;
}

_PointVisual _pointVisual(_VisitPointStatus status) {
  switch (status) {
    case _VisitPointStatus.completed:
      return const _PointVisual(
        SigmaColors.success,
        'Realizada · con pedido',
        Icons.check_circle_outline,
      );
    case _VisitPointStatus.ineffective:
      return const _PointVisual(
        SigmaColors.danger,
        'No efectiva · sin pedido',
        Icons.info_outline,
      );
    case _VisitPointStatus.pending:
      return const _PointVisual(
        SigmaColors.warning,
        'Pendiente',
        Icons.schedule_outlined,
      );
  }
}

class _RoutePoint {
  const _RoutePoint({
    required this.order,
    required this.name,
    required this.position,
    required this.status,
    this.clientId,
    this.plannedTime,
    this.visitTime,
    this.result,
    this.orderAmount,
    this.address,
  });

  final int order;
  final String name;
  final LatLng position;
  final _VisitPointStatus status;
  final int? clientId;
  final String? plannedTime;
  final DateTime? visitTime;
  final String? result;
  final double? orderAmount;
  final String? address;
}

class _RouteData {
  const _RouteData({
    required this.name,
    required this.zoneName,
    required this.points,
  });
  final String name;
  final String zoneName;
  final List<_RoutePoint> points;
}

class _TrackingMetrics {
  const _TrackingMetrics({
    required this.activeDuration,
    required this.distanceMeters,
    required this.pausedGaps,
  });
  final Duration activeDuration;
  final double distanceMeters;
  final int pausedGaps;
}

Map<String, dynamic> _mapOf(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

int? _intOf(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _doubleOf(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String? _nonEmptyText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

bool _validCoordinate(double lat, double lng) {
  return lat.isFinite &&
      lng.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180 &&
      !(lat == 0 && lng == 0);
}

String _dateText(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

String _distanceText(double meters) {
  if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
  return '${(meters / 1000).toStringAsFixed(2)} km';
}

String _durationText(Duration value) {
  if (value == Duration.zero) return '--';
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  if (hours > 0) return '$hours h ${minutes.toString().padLeft(2, '0')} min';
  return '${value.inMinutes} min';
}

String _money(dynamic value) {
  final number = value is num
      ? value.toDouble()
      : double.tryParse('$value') ?? 0;
  return NumberFormat('#,##0.00', 'en_US').format(number);
}

String _cleanError(Object error) => error
    .toString()
    .replaceFirst('Exception: ', '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
