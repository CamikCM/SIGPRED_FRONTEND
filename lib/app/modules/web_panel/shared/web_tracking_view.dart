import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../data/models/location_results.dart';
import '../../../data/models/paginated_response.dart';
import '../../../data/models/userlastlocation.dart';
import '../../../data/providers/location_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../utils/app_theme.dart';
import 'web_leaflet_map.dart';
import 'web_tracking_history_map.dart';
import '../layout/web_panel_shell.dart';

class WebTrackingView extends StatefulWidget {
  const WebTrackingView({
    super.key,
    this.activeRoute = Routes.webSupervisorTracking,
  });

  final String activeRoute;

  @override
  State<WebTrackingView> createState() => _WebTrackingViewState();
}

class _WebTrackingViewState extends State<WebTrackingView> {
  final LocationProvider _provider = Get.find<LocationProvider>();

  int? _selectedUserId;
  DateTime _selectedDate = DateTime.now();
  late Future<_TrackingData> _future;
  bool _liveMode = false;
  bool _liveRefreshInFlight = false;
  // SIGPRED 10.23.3 R2 · tracking remoto visual fluido Web
  LocationResult? _remoteVisualPosition;
  Timer? _remoteVisualTimer;
  int? _remoteVisualUserId;
  DateTime? _historyDateBeforeLive;
  Timer? _liveTimer;
  String? _historyFocusTarget;
  int _historyFocusSerial = 0;
  bool _routeInfoCollapsed = false;
  bool _assignedVisitsCollapsed = false;
  bool _calendarOpen = false;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _remoteVisualTimer?.cancel();
    super.dispose();
  }

  Future<_TrackingData> _loadData() async {
    final results = await Future.wait<dynamic>([
      _provider.getTrackableUsers(),
      _provider.getLastLocations(),
    ]);

    final users = List<Map<String, dynamic>>.from(
      results[0] as List<Map<String, dynamic>>,
    );
    final lastLocations = List<UserLastLocation>.from(
      results[1] as List<UserLastLocation>,
    );

    int? effectiveUserId = _selectedUserId;
    if (effectiveUserId == null ||
        !users.any((user) => _intValue(user['id']) == effectiveUserId)) {
      effectiveUserId = users.isEmpty ? null : _intValue(users.first['id']);
    }

    var history = <LocationResult>[];
    var visits = <Map<String, dynamic>>[];
    Map<String, dynamic>? assignedRoute;

    if (effectiveUserId != null) {
      final day = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final detailResults = await Future.wait<dynamic>([
        _provider.getUserLocations(
          userId: effectiveUserId,
          perPage: 1000,
          from: day,
          to: day,
        ),
        _provider.getAssignedRouteForDay(userId: effectiveUserId, date: day),
        _provider.getVisitsForDay(userId: effectiveUserId, date: day),
      ]);

      history = (detailResults[0] as PaginatedResponse<LocationResult>).data;
      assignedRoute = detailResults[1] as Map<String, dynamic>?;
      visits = List<Map<String, dynamic>>.from(
        detailResults[2] as List<Map<String, dynamic>>,
      );
    }

    return _TrackingData(
      users: users,
      lastLocations: lastLocations,
      history: history,
      visits: visits,
      assignedRoute: assignedRoute,
      selectedUserId: effectiveUserId,
    );
  }

  Future<void> _refresh() async {
    final next = _loadData();
    setState(() {
      _future = next;
    });
    await next;
  }

  LocationResult _visualLocationBetween(
    LocationResult from,
    LocationResult target,
    double t,
  ) {
    return LocationResult(
      latitude: from.latitude + (target.latitude - from.latitude) * t,
      longitude: from.longitude + (target.longitude - from.longitude) * t,
      capturedAt: target.capturedAt,
      updatedAt: target.updatedAt,
      accuracy: target.accuracy,
      source: target.source,
    );
  }

  void _setRemoteVisualDirect(LocationResult target, int userId) {
    _remoteVisualTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _remoteVisualUserId = userId;
      _remoteVisualPosition = target;
    });
  }

  void _animateRemoteMarkerTo(LocationResult target, int userId) {
    if (!mounted) return;

    final from = _remoteVisualPosition;
    _remoteVisualTimer?.cancel();

    if (from == null || _remoteVisualUserId != userId) {
      _setRemoteVisualDirect(target, userId);
      return;
    }

    final latDelta = (target.latitude - from.latitude).abs();
    final lngDelta = (target.longitude - from.longitude).abs();

    if (latDelta > 0.01 || lngDelta > 0.01) {
      _setRemoteVisualDirect(target, userId);
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
        _remoteVisualPosition = _visualLocationBetween(from, target, smoothT);
      });

      if (step >= steps) {
        timer.cancel();
        if (mounted) {
          setState(() => _remoteVisualPosition = target);
        }
      }
    });
  }

  LocationResult? _remoteTargetFromData(_TrackingData data) {
    final userId = data.selectedUserId ?? _selectedUserId;
    if (userId == null) return null;

    final validLocations = data.lastLocations.where(_isValidPoint).toList();
    final last = _selectedLast(validLocations, userId);
    return _latestLivePoint(data.history, last);
  }

  Future<void> _refreshLive() async {
    if (!_liveMode || _liveRefreshInFlight || !mounted) return;

    _liveRefreshInFlight = true;
    try {
      final next = _loadData();
      if (mounted) {
        setState(() {
          _future = next;
        });
      }
      final loaded = await next;
      final userId = loaded.selectedUserId ?? _selectedUserId;
      final target = _remoteTargetFromData(loaded);
      if (userId != null && target != null) {
        _animateRemoteMarkerTo(target, userId);
      }
    } finally {
      _liveRefreshInFlight = false;
    }
  }

  void _configureLiveTimer() {
    _liveTimer?.cancel();
    if (_liveMode) {
      _liveTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _refreshLive(),
      );
    }
  }

  Future<void> _enterLive() async {
    if (_liveMode) return;
    _remoteVisualTimer?.cancel();
    _remoteVisualPosition = null;
    _remoteVisualUserId = null;
    _historyDateBeforeLive = _selectedDate;
    setState(() {
      _liveMode = true;
      _selectedDate = DateTime.now();
      _historyFocusTarget = null;
      _future = _loadData();
    });
    _configureLiveTimer();
  }

  Future<void> _exitLive() async {
    _liveTimer?.cancel();
    _remoteVisualTimer?.cancel();
    _remoteVisualPosition = null;
    _remoteVisualUserId = null;
    if (!_liveMode) return;
    setState(() {
      _liveMode = false;
      _selectedDate = _historyDateBeforeLive ?? DateTime.now();
      _historyFocusTarget = null;
      _future = _loadData();
    });
  }

  Future<void> _changeVisitador(int? value) async {
    _remoteVisualTimer?.cancel();
    _remoteVisualPosition = null;
    _remoteVisualUserId = null;
    if (value == null) return;
    _liveTimer?.cancel();
    setState(() {
      _liveMode = false;
      _selectedUserId = value;
      _historyFocusTarget = null;
      _future = _loadData();
    });
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime get _firstHistoryDate => DateTime(DateTime.now().year - 5);

  bool get _canGoToPreviousDay =>
      _dateOnly(_selectedDate).isAfter(_dateOnly(_firstHistoryDate));

  bool get _canGoToNextDay =>
      _dateOnly(_selectedDate).isBefore(_dateOnly(DateTime.now()));

  Future<void> _applyHistoryDate(DateTime selected) async {
    _liveTimer?.cancel();

    setState(() {
      _liveMode = false;
      _selectedDate = _dateOnly(selected);
      _historyFocusTarget = null;
      _future = _loadData();
    });
  }

  Future<void> _moveHistoryDay(int delta) async {
    final candidate = _dateOnly(_selectedDate.add(Duration(days: delta)));
    final first = _dateOnly(_firstHistoryDate);
    final today = _dateOnly(DateTime.now());

    if (candidate.isBefore(first) || candidate.isAfter(today)) return;
    await _applyHistoryDate(candidate);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final wasLive = _liveMode;

    // HtmlElementView/iframe de Leaflet puede capturar eventos del mouse por
    // encima de overlays Flutter Web. Se retira temporalmente el mapa antes
    // de abrir el calendario para que el diálogo sea completamente interactivo.
    _liveTimer?.cancel();
    setState(() {
      _calendarOpen = true;
    });

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    DateTime? selected;
    try {
      selected = await showDatePicker(
        context: context,
        initialDate: _dateOnly(_selectedDate),
        firstDate: _dateOnly(_firstHistoryDate),
        lastDate: _dateOnly(now),
      );
    } finally {
      if (mounted) {
        setState(() {
          _calendarOpen = false;
        });
      }
    }

    if (!mounted) return;

    if (selected != null) {
      await _applyHistoryDate(selected);
      return;
    }

    // Si el usuario estaba supervisando en vivo y canceló el calendario,
    // se restaura únicamente el temporizador; no se cambia ningún dato.
    if (wasLive && _liveMode) {
      _configureLiveTimer();
    }
  }

  bool _isValidPoint(UserLastLocation item) {
    return item.latitude.isFinite &&
        item.longitude.isFinite &&
        item.latitude >= -90 &&
        item.latitude <= 90 &&
        item.longitude >= -180 &&
        item.longitude <= 180 &&
        !(item.latitude == 0 && item.longitude == 0);
  }

  bool _isValidHistoryPoint(LocationResult item) {
    return item.latitude.isFinite &&
        item.longitude.isFinite &&
        item.latitude >= -90 &&
        item.latitude <= 90 &&
        item.longitude >= -180 &&
        item.longitude <= 180 &&
        !(item.latitude == 0 && item.longitude == 0);
  }

  bool _isDemoTrackingSource(String? source) {
    final value = (source ?? '').trim().toLowerCase();
    return value.startsWith('demo_') || value.contains('demo_street');
  }

  LocationResult _lastLocationAsResult(UserLastLocation item) {
    return LocationResult(
      latitude: item.latitude,
      longitude: item.longitude,
      capturedAt: item.updatedAt,
      updatedAt: item.updatedAt,
      accuracy: item.accuracy,
      source: item.source,
    );
  }

  LocationResult? _latestLivePoint(
    List<LocationResult> history,
    UserLastLocation? last,
  ) {
    final maxAcceptedTime = DateTime.now().add(const Duration(minutes: 1));
    final candidates = <LocationResult>[];

    for (final item in history) {
      if (!_isValidHistoryPoint(item) ||
          _isDemoTrackingSource(item.source) ||
          item.capturedAt.toLocal().isAfter(maxAcceptedTime)) {
        continue;
      }
      candidates.add(item);
    }

    if (last != null &&
        _isValidPoint(last) &&
        !_isDemoTrackingSource(last.source) &&
        !last.updatedAt.toLocal().isAfter(maxAcceptedTime)) {
      candidates.add(_lastLocationAsResult(last));
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    return candidates.last;
  }

  bool _isLivePointOnline(LocationResult item) {
    final diff = DateTime.now().difference(item.capturedAt.toLocal());
    return !diff.isNegative && diff <= const Duration(minutes: 2);
  }

  int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  int _teamOnlineCount(
    List<Map<String, dynamic>> users,
    List<UserLastLocation> locations,
  ) {
    var total = 0;
    for (final user in users) {
      final id = _intValue(user['id']);
      if (id == null) continue;
      if (locations.any((item) => item.userId == id && _isOnline(item))) {
        total++;
      }
    }
    return total;
  }

  String _selectedName(List<Map<String, dynamic>> users, int? userId) {
    if (userId == null) return 'Visitador';
    for (final user in users) {
      if (_intValue(user['id']) == userId) {
        return (user['name'] ?? 'Visitador $userId').toString();
      }
    }
    return 'Visitador $userId';
  }

  UserLastLocation? _selectedLast(
    List<UserLastLocation> locations,
    int? userId,
  ) {
    if (userId == null) return null;
    for (final item in locations) {
      if (item.userId == userId) return item;
    }
    return null;
  }

  void _focusHistoryEndpoint(String target) {
    setState(() {
      _historyFocusSerial++;
      _historyFocusTarget = '${target}_$_historyFocusSerial';
    });
  }

  void _focusVisitPoint(WebAssignedVisitPoint point) {
    setState(() {
      _historyFocusSerial++;
      _historyFocusTarget = 'visit_${point.order}_$_historyFocusSerial';
    });
  }

  void _toggleRouteInfoPanel() {
    setState(() {
      _routeInfoCollapsed = !_routeInfoCollapsed;
    });
  }

  void _toggleAssignedVisitsPanel() {
    setState(() {
      _assignedVisitsCollapsed = !_assignedVisitsCollapsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WebPanelShell(
      title: 'Seguimiento por Visitador',
      subtitle:
          'Selecciona un visitador asignado y consulta el historial de ubicaciones GPS registrado por fecha.',
      badge: 'Supervisor',
      activeRoute: widget.activeRoute,
      child: FutureBuilder<_TrackingData>(
        future: _future,
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final data = snapshot.data;
          final users = data?.users ?? <Map<String, dynamic>>[];
          final allLocations = (data?.lastLocations ?? <UserLastLocation>[])
              .where(_isValidPoint)
              .toList();
          final history = data?.history ?? <LocationResult>[];
          final visitRecords = data?.visits ?? <Map<String, dynamic>>[];
          final visitPoints = _assignedVisitPoints(
            data?.assignedRoute,
            visitRecords,
          );
          final visitCounts = _visitStatusCounts(visitPoints);
          final effectiveUserId = data?.selectedUserId ?? _selectedUserId;
          final visitadorName = _selectedName(users, effectiveUserId);
          final current = _selectedLast(allLocations, effectiveUserId);
          final liveCurrent = _latestLivePoint(history, current);
          final mapCurrent =
              liveCurrent != null &&
                  _remoteVisualUserId == effectiveUserId &&
                  _remoteVisualPosition != null
              ? _remoteVisualPosition
              : liveCurrent;
          final selectedOnline =
              liveCurrent != null && _isLivePointOnline(liveCurrent);
          final teamOnline = _teamOnlineCount(users, allLocations);
          final teamWithGps = users.where((user) {
            final id = _intValue(user['id']);
            if (id == null) return false;
            return allLocations.any((item) => item.userId == id);
          }).length;
          final teamOffline = math.max(0, teamWithGps - teamOnline);
          final teamNoGps = math.max(0, users.length - teamWithGps);
          final trackingMetrics = _activeTrackingMetrics(history);
          final distance = trackingMetrics.distanceKm;
          final elapsedText = _formatElapsed(trackingMetrics.activeDuration);
          final timeRange = _historyTimeRange(history);
          final zoneName = _routeZoneName(data?.assignedRoute);
          final date = DateFormat('dd/MM/yyyy').format(_selectedDate);

          if (snapshot.hasError) {
            return _ErrorCard(error: snapshot.error.toString());
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FilterBar(
                date: date,
                zoneName: zoneName,
                users: users,
                selectedUserId: effectiveUserId,
                onVisitadorChanged: _changeVisitador,
                onDateTap: _pickDate,
                onPreviousDay: _canGoToPreviousDay
                    ? () => _moveHistoryDay(-1)
                    : null,
                onNextDay: _canGoToNextDay ? () => _moveHistoryDay(1) : null,
                onRefresh: _refresh,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _KpiCard(
                      icon: Icons.location_on_rounded,
                      title: 'Puntos GPS registrados',
                      value: isLoading ? '...' : '${history.length}',
                      footer: 'tracking_locations del día',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _KpiCard(
                      icon: Icons.route_rounded,
                      title: 'Distancia recorrida',
                      value: '${distance.toStringAsFixed(2)} km',
                      footer: trackingMetrics.continuousSegments == 0
                          ? 'Sin tramos GPS continuos'
                          : '${trackingMetrics.continuousSegments} tramos GPS '
                                'continuos · pausas excluidas',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _KpiCard(
                      icon: selectedOnline
                          ? Icons.wifi_rounded
                          : Icons.wifi_off_rounded,
                      title: 'Estado actual',
                      value: selectedOnline ? 'Online' : 'Offline',
                      footer: liveCurrent == null
                          ? 'Sin GPS real reciente'
                          : 'Último GPS real recibido',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _KpiCard(
                      icon: Icons.timelapse_rounded,
                      title: 'Tiempo activo estimado',
                      value: elapsedText,
                      footer: history.isEmpty
                          ? 'Sin recorrido GPS'
                          : trackingMetrics.pausedGaps > 0
                          ? '$timeRange · ${trackingMetrics.pausedGaps} '
                                'pausa(s)/corte(s) GPS excluidos'
                          : '$timeRange · GPS continuo',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _KpiCard(
                      icon: Icons.place_outlined,
                      title: 'Puntos asignados',
                      value: '${visitPoints.length}',
                      footer:
                          '${visitCounts.completed} realizadas · '
                          '${visitCounts.ineffective} no efectivas · '
                          '${visitCounts.pending} pendientes',
                    ),
                  ),
                ],
              ),
              if (selectedOnline || _liveMode) ...[
                const SizedBox(height: 14),
                _LiveActionBar(
                  online: selectedOnline,
                  liveMode: _liveMode,
                  visitadorName: visitadorName,
                  onEnterLive: _enterLive,
                  onExitLive: _exitLive,
                ),
              ],
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 8,
                    child: _calendarOpen
                        ? const _CalendarMapPlaceholder()
                        : _liveMode && selectedOnline && mapCurrent != null
                        ? _LiveMapPanel(
                            current: mapCurrent,
                            history: history,
                            visitPoints: visitPoints,
                            visitadorName: visitadorName,
                            focusTarget: _historyFocusTarget,
                          )
                        : _HistoryMapPanel(
                            items: history,
                            visitPoints: visitPoints,
                            visitadorName: visitadorName,
                            isLoading: isLoading,
                            date: date,
                            trackingMetrics: trackingMetrics,
                            focusTarget: _historyFocusTarget,
                          ),
                  ),
                  const SizedBox(width: 12),
                  if (_routeInfoCollapsed)
                    _CollapsedTrackingPanel(
                      icon: _liveMode
                          ? Icons.sensors_rounded
                          : Icons.alt_route_rounded,
                      tooltip: _liveMode
                          ? 'Mostrar estado en tiempo real'
                          : 'Mostrar inicio y fin',
                      onExpand: _toggleRouteInfoPanel,
                    )
                  else
                    Expanded(
                      flex: 2,
                      child: _liveMode && selectedOnline && liveCurrent != null
                          ? _LiveDetailsPanel(
                              current: liveCurrent,
                              routeName:
                                  data?.assignedRoute?['ruta_nombre']
                                      ?.toString() ??
                                  'Ruta del día',
                              pointCount: visitPoints.length,
                              onCollapse: _toggleRouteInfoPanel,
                            )
                          : _HistoryRecordsPanel(
                              items: history,
                              onFocusStart: () =>
                                  _focusHistoryEndpoint('start'),
                              onFocusEnd: () => _focusHistoryEndpoint('end'),
                              onCollapse: _toggleRouteInfoPanel,
                            ),
                    ),
                  const SizedBox(width: 12),
                  if (_assignedVisitsCollapsed)
                    _CollapsedTrackingPanel(
                      icon: Icons.flag_outlined,
                      tooltip: 'Mostrar puntos de visita asignados',
                      badge: visitPoints.length,
                      onExpand: _toggleAssignedVisitsPanel,
                    )
                  else
                    Expanded(
                      flex: 2,
                      child: _AssignedVisitsPanel(
                        route: data?.assignedRoute,
                        points: visitPoints,
                        history: history,
                        date: date,
                        onCollapse: _toggleAssignedVisitsPanel,
                        onFocusPoint: _focusVisitPoint,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _StatusFooter(
                total: users.length,
                online: teamOnline,
                offline: teamOffline,
                noGps: teamNoGps,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TrackingData {
  const _TrackingData({
    required this.users,
    required this.lastLocations,
    required this.history,
    required this.visits,
    required this.assignedRoute,
    required this.selectedUserId,
  });

  final List<Map<String, dynamic>> users;
  final List<UserLastLocation> lastLocations;
  final List<LocationResult> history;
  final List<Map<String, dynamic>> visits;
  final Map<String, dynamic>? assignedRoute;
  final int? selectedUserId;
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.date,
    required this.zoneName,
    required this.users,
    required this.selectedUserId,
    required this.onVisitadorChanged,
    required this.onDateTap,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onRefresh,
  });

  final String date;
  final String zoneName;
  final List<Map<String, dynamic>> users;
  final int? selectedUserId;
  final ValueChanged<int?> onVisitadorChanged;
  final VoidCallback onDateTap;
  final VoidCallback? onPreviousDay;
  final VoidCallback? onNextDay;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Expanded(
            child: _FilterField(
              label: 'Regional',
              value: 'Cochabamba',
              icon: Icons.location_city_outlined,
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: _FilterField(
              label: 'Zona',
              value: zoneName,
              icon: Icons.map_outlined,
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Visitador a supervisar',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: DropdownButtonFormField<int>(
                    value: selectedUserId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(color: Color(0xFFE3E7EF)),
                      ),
                    ),
                    hint: const Text('Sin visitadores asignados'),
                    items: users
                        .map((user) {
                          final raw = user['id'];
                          final id = raw is int
                              ? raw
                              : int.tryParse(raw?.toString() ?? '');
                          if (id == null) return null;
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(
                              (user['name'] ?? 'Visitador $id').toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        })
                        .whereType<DropdownMenuItem<int>>()
                        .toList(),
                    onChanged: users.isEmpty ? null : onVisitadorChanged,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: _DateFilterField(
              date: date,
              onTap: onDateTap,
              onPreviousDay: onPreviousDay,
              onNextDay: onNextDay,
            ),
          ),
          const SizedBox(width: 18),
          _PrimaryButton(
            label: 'Cargar historial',
            icon: Icons.route_outlined,
            onTap: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _DateFilterField extends StatelessWidget {
  const _DateFilterField({
    required this.date,
    required this.onTap,
    required this.onPreviousDay,
    required this.onNextDay,
  });

  final String date;
  final VoidCallback onTap;
  final VoidCallback? onPreviousDay;
  final VoidCallback? onNextDay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fecha del historial',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _DateArrowButton(
              tooltip: 'Día anterior',
              icon: Icons.chevron_left_rounded,
              onTap: onPreviousDay,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: const Color(0xFFE3E7EF)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          date,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.calendar_month_outlined,
                        size: 18,
                        color: Color(0xFF667085),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _DateArrowButton(
              tooltip: 'Día siguiente',
              icon: Icons.chevron_right_rounded,
              onTap: onNextDay,
            ),
          ],
        ),
      ],
    );
  }
}

class _DateArrowButton extends StatelessWidget {
  const _DateArrowButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            width: 36,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFFE3E7EF)),
            ),
            child: Icon(
              icon,
              size: 20,
              color: enabled
                  ? const Color(0xFF475467)
                  : const Color(0xFFD0D5DD),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterField extends StatelessWidget {
  const _FilterField({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFFE3E7EF)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Icon(icon, size: 19, color: const Color(0xFF667085)),
            ],
          ),
        ),
      ],
    );
  }
}

class _CalendarMapPlaceholder extends StatelessWidget {
  const _CalendarMapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 640,
        child: Container(
          alignment: Alignment.center,
          color: const Color(0xFFF8FAFC),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 34,
                color: Color(0xFF98A2B3),
              ),
              SizedBox(height: 10),
              Text(
                'Seleccionando fecha',
                style: TextStyle(
                  color: Color(0xFF344054),
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'El mapa se pausa visualmente mientras el calendario está abierto.',
                style: TextStyle(color: Color(0xFF667085), fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.footer,
  });
  final IconData icon;
  final String title;
  final String value;
  final String footer;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: SigmaColors.primary.withOpacity(.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: SigmaColors.primary, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF344054),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  footer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _MapPanel extends StatelessWidget {
  const _MapPanel({required this.items, required this.isLoading});
  final List<UserLastLocation> items;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final selected = items.isNotEmpty ? items.first : null;
    return _PanelCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const _PanelHeader(
            icon: Icons.map_outlined,
            title: 'Mapa de recorrido',
          ),
          SizedBox(
            height: 500,
            child: Stack(
              children: [
                Positioned.fill(child: WebLeafletMap(items: items)),
                if (selected != null)
                  Positioned(
                    left: 20,
                    bottom: 20,
                    child: _MapInfoCard(item: selected),
                  ),
                Positioned(
                  left: 14,
                  top: 14,
                  child: Column(
                    children: [
                      _MapControlButton(icon: Icons.add),
                      const SizedBox(height: 8),
                      _MapControlButton(icon: Icons.remove),
                      const SizedBox(height: 16),
                      _MapControlButton(icon: Icons.my_location_rounded),
                      const SizedBox(height: 8),
                      _MapControlButton(icon: Icons.layers_outlined),
                    ],
                  ),
                ),
                if (items.isEmpty && !isLoading)
                  const Center(child: _EmptyMapMessage()),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE8ECF3))),
            ),
            child: const Row(
              children: [
                _LegendDot(color: Color(0xFF23A455), label: 'Online'),
                SizedBox(width: 24),
                _LegendDot(color: Color(0xFF667085), label: 'Offline'),
                SizedBox(width: 24),
                _LegendDot(color: Color(0xFFFFB020), label: 'Sin actividad'),
                SizedBox(width: 24),
                _LegendDot(color: SigmaColors.primary, label: 'Inicio / Fin'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapInfoCard extends StatelessWidget {
  const _MapInfoCard({required this.item});
  final UserLastLocation item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.96),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.16),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.circle, color: Color(0xFF23A455), size: 10),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              const _TinyPill(label: 'ONLINE'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Punto actual: #${item.userId}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(
            'Precisión: ${item.accuracy?.toStringAsFixed(1) ?? '-'} m',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(
            'Latitud: ${item.latitude.toStringAsFixed(5)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(
            'Longitud: ${item.longitude.toStringAsFixed(5)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text(
            'Ver detalle',
            style: TextStyle(
              color: SigmaColors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordsPanel extends StatelessWidget {
  const _RecordsPanel({required this.items});
  final List<UserLastLocation> items;

  @override
  Widget build(BuildContext context) {
    final rows = items.take(8).toList();
    return _PanelCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            icon: Icons.calendar_today_outlined,
            title: 'Registros del día',
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE8ECF3))),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text('#', style: _TableHeadStyle.style),
                ),
                Expanded(child: Text('Hora', style: _TableHeadStyle.style)),
                Expanded(
                  child: Text('Prec. (m)', style: _TableHeadStyle.style),
                ),
                SizedBox(
                  width: 74,
                  child: Text('Conexión', style: _TableHeadStyle.style),
                ),
              ],
            ),
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Sin registros para mostrar.',
                style: TextStyle(
                  color: Color(0xFF667085),
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            ...rows.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final item = entry.value;
              return _RecordRow(index: index, item: item);
            }),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _OutlineWideButton(
              label: 'Ver todos los registros',
              icon: Icons.format_list_bulleted_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteSummaryPanel extends StatelessWidget {
  const _RouteSummaryPanel({required this.items});
  final List<UserLastLocation> items;

  @override
  Widget build(BuildContext context) {
    final rows = items.take(6).toList();
    return _PanelCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(
            icon: Icons.account_tree_outlined,
            title: 'Resumen de ruta',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              children: [
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Sin actividad GPS reciente.',
                      style: TextStyle(
                        color: Color(0xFF667085),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  ...rows.asMap().entries.map((entry) {
                    final item = entry.value;
                    final isLast = entry.key == rows.length - 1;
                    return _TimelineItem(
                      time: DateFormat(
                        'HH:mm:ss',
                      ).format(item.updatedAt.toLocal()),
                      title: entry.key == 0
                          ? 'Último reporte GPS'
                          : 'Ubicación registrada',
                      subtitle: item.name,
                      isLast: isLast,
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: _OutlineWideButton(
              label: 'Ver ruta completa',
              icon: Icons.map_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveActionBar extends StatelessWidget {
  const _LiveActionBar({
    required this.online,
    required this.liveMode,
    required this.visitadorName,
    required this.onEnterLive,
    required this.onExitLive,
  });

  final bool online;
  final bool liveMode;
  final String visitadorName;
  final VoidCallback onEnterLive;
  final VoidCallback onExitLive;

  @override
  Widget build(BuildContext context) {
    final active = online && liveMode;
    final color = online ? const Color(0xFF12B76A) : const Color(0xFFB54708);

    return _PanelCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              online
                  ? Icons.wifi_tethering_rounded
                  : Icons.signal_wifi_connected_no_internet_4_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active
                      ? 'Supervisión en vivo activa'
                      : online
                      ? '$visitadorName está Online'
                      : 'Se perdió la conexión en vivo',
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  active
                      ? 'La posición se actualiza cada 15 segundos y se muestran los puntos de visita asignados.'
                      : online
                      ? 'Puedes abrir el mapa en vivo sin perder el historial por fecha.'
                      : 'El historial continúa disponible. Vuelve a intentarlo cuando llegue un GPS reciente.',
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (liveMode)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 170, maxWidth: 210),
              child: OutlinedButton.icon(
                onPressed: onExitLive,
                icon: const Icon(Icons.history_rounded),
                label: const Text('Volver al historial'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  maximumSize: const Size(210, 52),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            )
          else if (online)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 180, maxWidth: 220),
              child: FilledButton.icon(
                onPressed: onEnterLive,
                icon: const Icon(Icons.location_searching_rounded),
                label: const Text('Supervisar en vivo'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF12B76A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 44),
                  maximumSize: const Size(220, 52),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LiveMapPanel extends StatelessWidget {
  const _LiveMapPanel({
    required this.current,
    required this.history,
    required this.visitPoints,
    required this.visitadorName,
    required this.focusTarget,
  });

  final LocationResult current;
  final List<LocationResult> history;
  final List<WebAssignedVisitPoint> visitPoints;
  final String visitadorName;
  final String? focusTarget;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const _PanelHeader(
            icon: Icons.location_searching_rounded,
            title: 'Supervisión en vivo',
          ),
          SizedBox(
            height: 420,
            child: WebTrackingHistoryMap(
              items: _liveHistoryWithCurrent(history, current),
              visitadorName: visitadorName,
              visitPoints: visitPoints,
              liveMode: true,
              focusTarget: focusTarget,
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE8ECF3))),
            ),
            child: Wrap(
              spacing: 18,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const _LegendDot(color: Color(0xFF0EA5E9), label: 'Inicio'),
                const _LegendDot(
                  color: Color(0xFF7C3AED),
                  label: 'Ubicación actual',
                ),
                const _LegendDot(color: Color(0xFF12B76A), label: 'Realizada'),
                const _LegendDot(
                  color: Color(0xFFF04438),
                  label: 'No efectiva',
                ),
                const _LegendDot(color: Color(0xFFF79009), label: 'Pendiente'),
                Text(
                  'Actualización automática cada 15 s · '
                  '${visitPoints.length} punto(s) asignado(s)',
                  style: const TextStyle(
                    color: Color(0xFF344054),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
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

class _LiveDetailsPanel extends StatelessWidget {
  const _LiveDetailsPanel({
    required this.current,
    required this.routeName,
    required this.pointCount,
    required this.onCollapse,
  });

  final LocationResult current;
  final String routeName;
  final int pointCount;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TrackingPanelHeader(
            icon: Icons.sensors_rounded,
            title: 'Estado en tiempo real',
            onCollapse: onCollapse,
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _TinyPill(label: 'ONLINE'),
                const SizedBox(height: 14),
                _LiveDetailRow(
                  icon: Icons.schedule_rounded,
                  label: 'Último GPS',
                  value: DateFormat(
                    'dd/MM/yyyy HH:mm:ss',
                  ).format(current.capturedAt.toLocal()),
                ),
                _LiveDetailRow(
                  icon: Icons.gps_fixed_rounded,
                  label: 'Precisión',
                  value: '${current.accuracy?.toStringAsFixed(1) ?? '-'} m',
                ),
                _LiveDetailRow(
                  icon: Icons.my_location_rounded,
                  label: 'Coordenadas',
                  value:
                      '${current.latitude.toStringAsFixed(6)}, ${current.longitude.toStringAsFixed(6)}',
                ),
                _LiveDetailRow(
                  icon: Icons.alt_route_rounded,
                  label: 'Ruta',
                  value: routeName,
                ),
                _LiveDetailRow(
                  icon: Icons.flag_outlined,
                  label: 'Puntos de visita',
                  value: '$pointCount asignado(s)',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveDetailRow extends StatelessWidget {
  const _LiveDetailRow({
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
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: SigmaColors.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
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

class _HistoryMapPanel extends StatelessWidget {
  const _HistoryMapPanel({
    required this.items,
    required this.visitPoints,
    required this.visitadorName,
    required this.isLoading,
    required this.date,
    required this.trackingMetrics,
    required this.focusTarget,
  });

  final List<LocationResult> items;
  final List<WebAssignedVisitPoint> visitPoints;
  final String visitadorName;
  final bool isLoading;
  final String date;
  final _ActiveTrackingMetrics trackingMetrics;
  final String? focusTarget;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const _PanelHeader(
            icon: Icons.map_outlined,
            title: 'Historial de ubicaciones',
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE7EAF0)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 17,
                  color: SigmaColors.primary,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Usa los controles del mapa para revisar el recorrido. '
                    'Haz clic en una visita para ver su información.',
                    style: TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 540,
            child: Stack(
              children: [
                Positioned.fill(
                  child: WebTrackingHistoryMap(
                    items: items,
                    visitadorName: visitadorName,
                    visitPoints: visitPoints,
                    focusTarget: focusTarget,
                  ),
                ),
                if (items.isEmpty && !isLoading)
                  const Center(child: _EmptyHistoryMessage()),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
            decoration: const BoxDecoration(
              color: Color(0xFFFCFCFD),
              border: Border(top: BorderSide(color: Color(0xFFE8ECF3))),
            ),
            child: const Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MapLegendBadge(color: Color(0xFF0EA5E9), label: 'Inicio'),
                _MapLegendBadge(
                  color: Color(0xFF7C3AED),
                  label: 'Fin / última ubicación',
                ),
                _MapLegendBadge(color: Color(0xFF12B76A), label: 'Realizada'),
                _MapLegendBadge(color: Color(0xFFF04438), label: 'No efectiva'),
                _MapLegendBadge(color: Color(0xFFF79009), label: 'Pendiente'),
                _MapLegendLineBadge(label: 'Recorrido GPS'),
              ],
            ),
          ),
          if (items.isNotEmpty)
            _TrackingQualityPanel(
              count: items.length,
              date: date,
              metrics: trackingMetrics,
            ),
        ],
      ),
    );
  }
}

class _MapLegendBadge extends StatelessWidget {
  const _MapLegendBadge({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF475467),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapLegendLineBadge extends StatelessWidget {
  const _MapLegendLineBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.timeline_rounded,
            size: 15,
            color: SigmaColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF475467),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingQualityPanel extends StatefulWidget {
  const _TrackingQualityPanel({
    required this.count,
    required this.date,
    required this.metrics,
  });

  final int count;
  final String date;
  final _ActiveTrackingMetrics metrics;

  @override
  State<_TrackingQualityPanel> createState() => _TrackingQualityPanelState();
}

class _TrackingQualityPanelState extends State<_TrackingQualityPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final accuracy = widget.metrics.averageAccuracy == null
        ? 'Sin dato'
        : '${widget.metrics.averageAccuracy!.toStringAsFixed(1)} m';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8ECF3))),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: SigmaColors.primary.withOpacity(.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.sensors_rounded,
                        color: SigmaColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Calidad del tracking GPS',
                            style: TextStyle(
                              color: Color(0xFF101828),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.count} puntos · '
                            '${widget.metrics.continuousSegments} tramos · '
                            'precisión $accuracy',
                            style: const TextStyle(
                              color: Color(0xFF667085),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: const Color(0xFFE4E7EC)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _expanded ? 'Ocultar' : 'Ver detalle',
                            style: const TextStyle(
                              color: Color(0xFF475467),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _expanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 17,
                            color: const Color(0xFF667085),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final metrics = <Widget>[
                    _TrackingQualityMetric(
                      icon: Icons.gps_fixed_rounded,
                      label: 'GPS registrados',
                      value: '${widget.count}',
                    ),
                    _TrackingQualityMetric(
                      icon: Icons.route_outlined,
                      label: 'Tramos continuos',
                      value: '${widget.metrics.continuousSegments}',
                    ),
                    _TrackingQualityMetric(
                      icon: Icons.pause_circle_outline_rounded,
                      label: 'Cortes detectados',
                      value: '${widget.metrics.pausedGaps}',
                    ),
                    _TrackingQualityMetric(
                      icon: Icons.report_gmailerrorred_outlined,
                      label: 'Saltos descartados',
                      value: '${widget.metrics.rejectedJumps}',
                    ),
                    _TrackingQualityMetric(
                      icon: Icons.my_location_rounded,
                      label: 'Precisión promedio',
                      value: accuracy,
                    ),
                  ];

                  if (constraints.maxWidth < 720) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: metrics
                          .map(
                            (item) => SizedBox(
                              width: (constraints.maxWidth - 8) / 2,
                              child: item,
                            ),
                          )
                          .toList(),
                    );
                  }

                  return Row(
                    children: [
                      for (var i = 0; i < metrics.length; i++) ...[
                        Expanded(child: metrics[i]),
                        if (i != metrics.length - 1) const SizedBox(width: 8),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: Color(0xFF667085),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${widget.date} · Los cortes GPS se excluyen del '
                      'tiempo activo estimado y de la distancia continua.',
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 10.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
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

class _TrackingQualityMetric extends StatelessWidget {
  const _TrackingQualityMetric({
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
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE7EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: SigmaColors.primary),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF101828),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 9.8,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRecordsPanel extends StatelessWidget {
  const _HistoryRecordsPanel({
    required this.items,
    required this.onFocusStart,
    required this.onFocusEnd,
    required this.onCollapse,
  });

  final List<LocationResult> items;
  final VoidCallback onFocusStart;
  final VoidCallback onFocusEnd;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TrackingPanelHeader(
            icon: Icons.alt_route_rounded,
            title: 'Inicio y fin del recorrido',
            onCollapse: onCollapse,
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Sin tracking_locations para esta fecha.',
                style: TextStyle(
                  color: Color(0xFF667085),
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                '${items.length} puntos GPS forman el recorrido. '
                'Selecciona Inicio o Fin para ubicarlo en el mapa.',
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 11.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _HistoryEndpointRow(
              color: const Color(0xFF0EA5E9),
              icon: Icons.play_circle_outline_rounded,
              title: 'Inicio',
              indexLabel: 'GPS #1',
              item: items.first,
              onTap: onFocusStart,
            ),
            _HistoryEndpointConnector(),
            _HistoryEndpointRow(
              color: const Color(0xFF7C3AED),
              icon: Icons.flag_circle_outlined,
              title: 'Fin / última ubicación',
              indexLabel: 'GPS #${items.length}',
              item: items.last,
              onTap: onFocusEnd,
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF0F2F6))),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Color(0xFF667085),
                  ),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Haz clic en Inicio o Fin para acercar el mapa. '
                      'La línea rosa conserva todos los puntos GPS intermedios.',
                      style: TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 10.8,
                        height: 1.3,
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
}

class _HistoryEndpointRow extends StatelessWidget {
  const _HistoryEndpointRow({
    required this.color,
    required this.icon,
    required this.title,
    required this.indexLabel,
    required this.item,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String indexLabel;
  final LocationResult item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final local = item.capturedAt.toLocal();

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          indexLabel,
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      DateFormat('HH:mm:ss').format(local),
                      style: const TextStyle(
                        color: Color(0xFF344054),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Precisión: ${item.accuracy?.toStringAsFixed(1) ?? '--'} m',
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 10.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.my_location_rounded, color: color, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryEndpointConnector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      margin: const EdgeInsets.only(left: 34),
      alignment: Alignment.centerLeft,
      child: Container(width: 2, height: 26, color: const Color(0xFFE4E7EC)),
    );
  }
}

class _AssignedVisitsPanel extends StatelessWidget {
  const _AssignedVisitsPanel({
    required this.route,
    required this.points,
    required this.history,
    required this.date,
    required this.onCollapse,
    required this.onFocusPoint,
  });

  final Map<String, dynamic>? route;
  final List<WebAssignedVisitPoint> points;
  final List<LocationResult> history;
  final String date;
  final VoidCallback onCollapse;
  final ValueChanged<WebAssignedVisitPoint> onFocusPoint;

  @override
  Widget build(BuildContext context) {
    final rawRouteName = route?['ruta_nombre']?.toString().trim() ?? '';
    final routeName = rawRouteName.isEmpty
        ? 'Puntos asignados del día'
        : rawRouteName;
    final counts = _visitStatusCounts(points);

    return _PanelCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TrackingPanelHeader(
            icon: Icons.flag_outlined,
            title: 'Puntos de visita asignados',
            onCollapse: onCollapse,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  routeName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$date · ${points.length} punto(s)',
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (points.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Haz clic en un punto para ubicarlo y abrir su detalle. Los puntos no representan un orden obligatorio de recorrido.',
                    style: TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 9.8,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _VisitStatusChip(
                        color: const Color(0xFF12B76A),
                        label: '${counts.completed} realizadas',
                      ),
                      _VisitStatusChip(
                        color: const Color(0xFFF04438),
                        label: '${counts.ineffective} no efectivas',
                      ),
                      _VisitStatusChip(
                        color: const Color(0xFFF79009),
                        label: '${counts.pending} pendientes',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (points.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'El visitador no tiene puntos de visita georreferenciados para esta fecha.',
                style: TextStyle(
                  color: Color(0xFF667085),
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            ...points.map((point) {
              final near = _historyPassedNear(history, point, 90);
              final visual = _visitVisual(point.status);
              final visitTime = point.visitTime == null
                  ? null
                  : DateFormat('HH:mm').format(point.visitTime!.toLocal());

              final detail = switch (point.status) {
                WebAssignedVisitStatus.completed =>
                  visitTime == null
                      ? 'Realizada · con pedido'
                      : 'Realizada $visitTime · con pedido',
                WebAssignedVisitStatus.ineffective =>
                  visitTime == null
                      ? 'No efectiva · sin pedido'
                      : 'No efectiva $visitTime · sin pedido',
                WebAssignedVisitStatus.pending =>
                  near
                      ? 'Pendiente · el GPS pasó cerca, pero no hay visita registrada'
                      : point.plannedTime?.isNotEmpty == true
                      ? 'Pendiente · hora planificada ${point.plannedTime}'
                      : 'Pendiente · sin visita registrada',
              };

              return Material(
                color: Colors.white,
                child: InkWell(
                  onTap: () => onFocusPoint(point),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
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
                            color: visual.color.withOpacity(.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: visual.color.withOpacity(.28),
                            ),
                          ),
                          child: Text(
                            '•',
                            style: TextStyle(
                              color: visual.color,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                point.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                detail,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color:
                                      point.status ==
                                          WebAssignedVisitStatus.pending
                                      ? const Color(0xFF667085)
                                      : visual.color,
                                  fontSize: 10.4,
                                  height: 1.25,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const SizedBox(width: 3),
                        Tooltip(
                          message: 'Ubicar en mapa',
                          child: Icon(
                            Icons.my_location_rounded,
                            size: 16,
                            color: visual.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _VisitStatusChip extends StatelessWidget {
  const _VisitStatusChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(.16)),
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
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitStatusPill extends StatelessWidget {
  const _VisitStatusPill({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 90),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 9.3,
          height: 1.15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _VisitVisual {
  const _VisitVisual({required this.color, required this.label});

  final Color color;
  final String label;
}

_VisitVisual _visitVisual(WebAssignedVisitStatus status) {
  switch (status) {
    case WebAssignedVisitStatus.completed:
      return const _VisitVisual(color: Color(0xFF12B76A), label: 'Realizada');
    case WebAssignedVisitStatus.ineffective:
      return const _VisitVisual(color: Color(0xFFF04438), label: 'No efectiva');
    case WebAssignedVisitStatus.pending:
      return const _VisitVisual(color: Color(0xFFF79009), label: 'Pendiente');
  }
}

class _EmptyHistoryMessage extends StatelessWidget {
  const _EmptyHistoryMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.96),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 18),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.route_outlined, size: 30, color: Color(0xFF98A2B3)),
          SizedBox(height: 8),
          Text(
            'No existen puntos de recorrido para visualizar',
            style: TextStyle(
              color: Color(0xFF344054),
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Cambia la fecha para consultar otro día.',
            style: TextStyle(color: Color(0xFF667085), fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _StatusFooter extends StatelessWidget {
  const _StatusFooter({
    required this.total,
    required this.online,
    required this.offline,
    required this.noGps,
  });
  final int total;
  final int online;
  final int offline;
  final int noGps;

  @override
  Widget build(BuildContext context) {
    final onlinePercent = total == 0 ? 0 : ((online / total) * 100).round();
    final offlinePercent = total == 0 ? 0 : ((offline / total) * 100).round();
    final noGpsPercent = total == 0 ? 0 : ((noGps / total) * 100).round();
    return _PanelCard(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      child: Row(
        children: [
          const Text(
            'Estado del equipo en campo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF667085),
            size: 18,
          ),
          const Spacer(),
          _FooterStatus(
            icon: Icons.wifi_rounded,
            label: 'Online',
            value: '$online',
            percent: '$onlinePercent%',
            color: const Color(0xFF23A455),
          ),
          const _VerticalSeparator(),
          _FooterStatus(
            icon: Icons.wifi_off_rounded,
            label: 'Offline',
            value: '$offline',
            percent: '$offlinePercent%',
            color: const Color(0xFF667085),
          ),
          const _VerticalSeparator(),
          _FooterStatus(
            icon: Icons.location_off_outlined,
            label: 'Sin GPS',
            value: '$noGps',
            percent: '$noGpsPercent%',
            color: const Color(0xFFFFB020),
          ),
          const SizedBox(width: 28),
          const Flexible(
            child: Text(
              'Online: GPS ≤ 2 min · Offline: último GPS > 2 min · '
              'Sin GPS: aún no existe ubicación registrada.',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Color(0xFF667085),
                fontSize: 10.5,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECF3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _TrackingPanelHeader extends StatelessWidget {
  const _TrackingPanelHeader({
    required this.icon,
    required this.title,
    required this.onCollapse,
  });

  final IconData icon;
  final String title;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 15, 10, 11),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF344054), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                height: 1.15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ),
          Tooltip(
            message: 'Minimizar',
            child: IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onCollapse,
              icon: const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Color(0xFF667085),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsedTrackingPanel extends StatelessWidget {
  const _CollapsedTrackingPanel({
    required this.icon,
    required this.tooltip,
    required this.onExpand,
    this.badge,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onExpand;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: _PanelCard(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onExpand,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: SigmaColors.primary, size: 22),
                  if (badge != null && badge! > 0)
                    Positioned(
                      right: 1,
                      top: -8,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 18),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: SigmaColors.primary,
                          borderRadius: BorderRadius.all(Radius.circular(99)),
                        ),
                        child: Text(
                          '$badge',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF344054), size: 22),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: SigmaColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(140, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF344054),
        side: const BorderSide(color: SigmaColors.primary),
        minimumSize: const Size(108, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _OutlineWideButton extends StatelessWidget {
  const _OutlineWideButton({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: SigmaColors.primary,
        side: const BorderSide(color: Color(0xFFE8ECF3)),
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.14), blurRadius: 14),
        ],
      ),
      child: Icon(icon, color: const Color(0xFF344054), size: 20),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F8ED),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF23A455),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.circle, color: color, size: 10),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF667085),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.index, required this.item});
  final int index;
  final UserLastLocation item;

  @override
  Widget build(BuildContext context) {
    final online = _isOnline(item);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F2F6))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '$index',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              DateFormat('HH:mm:ss').format(item.updatedAt.toLocal()),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              (item.accuracy ?? 0).toStringAsFixed(1),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
          SizedBox(
            width: 74,
            child: _StatusChip(
              label: online ? 'ONLINE' : 'OFFLINE',
              online: online,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.online});
  final String label;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: online ? const Color(0xFFE7F8ED) : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: online ? const Color(0xFF23A455) : const Color(0xFF667085),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.isLast,
  });
  final String time;
  final String title;
  final String subtitle;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              time,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: SigmaColors.primary, width: 3),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 3, color: SigmaColors.primary),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterStatus extends StatelessWidget {
  const _FooterStatus({
    required this.icon,
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final String percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: color.withOpacity(.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              percent,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VerticalSeparator extends StatelessWidget {
  const _VerticalSeparator();
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 58,
    margin: const EdgeInsets.symmetric(horizontal: 28),
    color: const Color(0xFFE8ECF3),
  );
}

class _EmptyMapMessage extends StatelessWidget {
  const _EmptyMapMessage();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.94),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.14), blurRadius: 20),
        ],
      ),
      child: const Text(
        'Sin puntos GPS válidos para mostrar.',
        style: TextStyle(color: Color(0xFF667085), fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});
  final String error;
  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Text(
        'No se pudo cargar tracking: $error',
        style: const TextStyle(
          color: SigmaColors.danger,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TableHeadStyle {
  static const style = TextStyle(
    color: Color(0xFF111827),
    fontWeight: FontWeight.w900,
    fontSize: 12,
  );
}

bool _isOnline(UserLastLocation item) {
  final diff = DateTime.now().difference(item.updatedAt.toLocal());
  return !diff.isNegative && diff <= const Duration(minutes: 2);
}

List<WebAssignedVisitPoint> _assignedVisitPoints(
  Map<String, dynamic>? route,
  List<Map<String, dynamic>> visits,
) {
  final raw = route?['detalles'];
  if (raw is! List) return <WebAssignedVisitPoint>[];

  final latestVisitByClient = <int, Map<String, dynamic>>{};

  for (final visit in visits) {
    final clientId = _visitClientId(visit);
    if (clientId == null) continue;

    final current = latestVisitByClient[clientId];
    if (current == null ||
        _visitDateTime(visit).isAfter(_visitDateTime(current))) {
      latestVisitByClient[clientId] = visit;
    }
  }

  final points = <WebAssignedVisitPoint>[];

  for (final item in raw.whereType<Map>()) {
    final detail = Map<String, dynamic>.from(item);
    final clientRaw = detail['cliente'];
    if (clientRaw is! Map) continue;
    final client = Map<String, dynamic>.from(clientRaw);

    final lat = _toDouble(client['cliente_lat']);
    final lng = _toDouble(client['cliente_lng']);
    if (lat == null || lng == null) continue;

    final clientId =
        _toInt(detail['cliente_id']) ??
        _toInt(client['cliente_id']) ??
        _toInt(client['id']);
    final visit = clientId == null ? null : latestVisitByClient[clientId];

    WebAssignedVisitStatus status = WebAssignedVisitStatus.pending;
    DateTime? visitTime;
    String? result;

    if (visit != null) {
      final effective =
          _toBool(visit['efectiva'] ?? visit['vis_efectiva']) ||
          _visitHasOrder(visit);
      status = effective
          ? WebAssignedVisitStatus.completed
          : WebAssignedVisitStatus.ineffective;
      visitTime = _visitDateTimeOrNull(visit);
      result = _visitResult(visit);
    }

    points.add(
      WebAssignedVisitPoint(
        order: _toInt(detail['orden_visita']) ?? (points.length + 1),
        name: (client['cliente_nombre'] ?? 'Punto de visita').toString(),
        latitude: lat,
        longitude: lng,
        clientId: clientId,
        plannedTime: detail['hora_planificada']?.toString(),
        status: status,
        visitTime: visitTime,
        result: result,
        clientType: _trackingClientType(client),
        zoneName: _trackingClientZone(client),
        address: _trackingNonEmptyText(client['cliente_dir']),
        phone: _trackingNonEmptyText(client['cliente_telefono']),
        reference: _trackingNonEmptyText(client['cliente_referencia']),
        orderAmount: visit == null ? null : _visitOrderAmount(visit),
      ),
    );
  }

  points.sort((a, b) => a.order.compareTo(b.order));
  return points;
}

String? _trackingNonEmptyText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

String? _trackingClientType(Map<String, dynamic> client) {
  final direct = _trackingNonEmptyText(
    client['tipo_cliente_nombre'] ?? client['tc_nombre'],
  );
  if (direct != null) return direct;

  final nested = client['tipo_cliente'];
  if (nested is Map) {
    final map = Map<String, dynamic>.from(nested);
    return _trackingNonEmptyText(
      map['tc_nombre'] ?? map['nombre'] ?? map['name'],
    );
  }
  return null;
}

String? _trackingClientZone(Map<String, dynamic> client) {
  final direct = _trackingNonEmptyText(
    client['zona_nombre'] ?? client['zon_nombre'] ?? client['zone_name'],
  );
  if (direct != null) return direct;

  final nested = client['zona'];
  if (nested is Map) {
    final map = Map<String, dynamic>.from(nested);
    return _trackingNonEmptyText(
      map['zona_nombre'] ?? map['zon_nombre'] ?? map['nombre'] ?? map['name'],
    );
  }
  return null;
}

double? _visitOrderAmount(Map<String, dynamic> visit) {
  final pedido = visit['pedido'];
  if (pedido is Map) {
    final map = Map<String, dynamic>.from(pedido);
    return _toDouble(
      map['monto_total'] ?? map['ped_monto_total'] ?? map['total'],
    );
  }
  return _toDouble(visit['monto_pedido'] ?? visit['monto_total_pedido']);
}

int? _visitClientId(Map<String, dynamic> visit) {
  final nested = visit['cliente'];
  if (nested is Map) {
    final map = Map<String, dynamic>.from(nested);
    final id = _toInt(map['cliente_id'] ?? map['id']);
    if (id != null) return id;
  }

  return _toInt(
    visit['cliente_id'] ?? visit['cli_id'] ?? visit['vis_cliente_id'],
  );
}

bool _visitHasOrder(Map<String, dynamic> visit) {
  final pedido = visit['pedido'];
  return pedido is Map && pedido.isNotEmpty;
}

bool _toBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final raw = value?.toString().trim().toLowerCase() ?? '';
  return raw == 'true' || raw == '1' || raw == 'si' || raw == 'sí';
}

DateTime _visitDateTime(Map<String, dynamic> visit) =>
    _visitDateTimeOrNull(visit) ?? DateTime.fromMillisecondsSinceEpoch(0);

DateTime? _visitDateTimeOrNull(Map<String, dynamic> visit) {
  final raw =
      visit['fecha_inicio'] ?? visit['vis_fecha_inicio'] ?? visit['created_at'];
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString());
}

String? _visitResult(Map<String, dynamic> visit) {
  final raw = visit['resultado'] ?? visit['vis_resultado'] ?? visit['motivo'];
  final value = raw?.toString().trim() ?? '';
  return value.isEmpty ? null : value;
}

_VisitStatusCounts _visitStatusCounts(List<WebAssignedVisitPoint> points) {
  var completed = 0;
  var ineffective = 0;
  var pending = 0;

  for (final point in points) {
    switch (point.status) {
      case WebAssignedVisitStatus.completed:
        completed++;
        break;
      case WebAssignedVisitStatus.ineffective:
        ineffective++;
        break;
      case WebAssignedVisitStatus.pending:
        pending++;
        break;
    }
  }

  return _VisitStatusCounts(
    completed: completed,
    ineffective: ineffective,
    pending: pending,
  );
}

class _VisitStatusCounts {
  const _VisitStatusCounts({
    required this.completed,
    required this.ineffective,
    required this.pending,
  });

  final int completed;
  final int ineffective;
  final int pending;
}

List<LocationResult> _liveHistoryWithCurrent(
  List<LocationResult> history,
  LocationResult current,
) {
  final result = <LocationResult>[...history];

  final alreadyIncluded = result.any(
    (item) =>
        item.capturedAt.millisecondsSinceEpoch ==
            current.capturedAt.millisecondsSinceEpoch &&
        (item.latitude - current.latitude).abs() < .0000001 &&
        (item.longitude - current.longitude).abs() < .0000001,
  );

  if (!alreadyIncluded) {
    result.add(current);
  }

  result.sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
  return result;
}

bool _historyPassedNear(
  List<LocationResult> history,
  WebAssignedVisitPoint point,
  double radiusMeters,
) {
  for (final item in history) {
    final km = _haversine(
      item.latitude,
      item.longitude,
      point.latitude,
      point.longitude,
    );
    if (km * 1000 <= radiusMeters) return true;
  }
  return false;
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

String _formatElapsed(Duration value) {
  if (value == Duration.zero) return '--';
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);

  if (hours > 0) {
    return '$hours h ${minutes.toString().padLeft(2, '0')} min';
  }
  return '${value.inMinutes} min';
}

String _routeZoneName(Map<String, dynamic>? route) {
  if (route == null) return 'Sin zona asignada';

  String? textValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  final direct = textValue(
    route['zona_nombre'] ??
        route['zon_nombre'] ??
        route['zone_name'] ??
        route['ruta_zona_nombre'],
  );
  if (direct != null) return direct;

  final zone = route['zona'];
  if (zone is Map) {
    final map = Map<String, dynamic>.from(zone);
    final nested = textValue(
      map['zona_nombre'] ?? map['zon_nombre'] ?? map['nombre'] ?? map['name'],
    );
    if (nested != null) return nested;
  }

  final details = route['detalles'];
  if (details is List) {
    for (final raw in details.whereType<Map>()) {
      final detail = Map<String, dynamic>.from(raw);
      final detailZone = textValue(
        detail['zona_nombre'] ?? detail['zon_nombre'],
      );
      if (detailZone != null) return detailZone;

      final client = detail['cliente'];
      if (client is Map) {
        final map = Map<String, dynamic>.from(client);
        final clientZone = textValue(
          map['zona_nombre'] ?? map['zon_nombre'] ?? map['zone_name'],
        );
        if (clientZone != null) return clientZone;

        final nestedZone = map['zona'];
        if (nestedZone is Map) {
          final nestedMap = Map<String, dynamic>.from(nestedZone);
          final nestedName = textValue(
            nestedMap['zona_nombre'] ??
                nestedMap['zon_nombre'] ??
                nestedMap['nombre'] ??
                nestedMap['name'],
          );
          if (nestedName != null) return nestedName;
        }
      }
    }
  }

  return 'Zona no informada';
}

const Duration _trackingContinuityGap = Duration(minutes: 2);

_ActiveTrackingMetrics _activeTrackingMetrics(List<LocationResult> items) {
  if (items.length < 2) {
    return const _ActiveTrackingMetrics(
      activeDuration: Duration.zero,
      distanceKm: 0,
      continuousSegments: 0,
      pausedGaps: 0,
      rejectedJumps: 0,
      averageAccuracy: null,
    );
  }

  final ordered = <LocationResult>[...items]
    ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));

  var activeDuration = Duration.zero;
  var distanceKm = 0.0;
  var continuousSegments = 0;
  var pausedGaps = 0;
  var rejectedJumps = 0;

  for (var i = 1; i < ordered.length; i++) {
    final previous = ordered[i - 1];
    final current = ordered[i];
    final gap = current.capturedAt.difference(previous.capturedAt);

    if (gap <= Duration.zero) continue;

    // Un intervalo largo se considera pausa/corte de tracking.
    // No unimos artificialmente ambos extremos como si el Visitador
    // hubiera recorrido en línea recta ese tramo mientras el GPS estaba pausado.
    if (gap > _trackingContinuityGap) {
      pausedGaps++;
      continue;
    }

    final segmentKm = _haversine(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );

    final hours = gap.inMilliseconds / 3600000.0;
    final speedKmh = hours <= 0 ? 0.0 : segmentKm / hours;

    // Protección contra saltos GPS evidentemente anómalos.
    // 160 km/h deja margen suficiente para traslados en vehículo,
    // pero evita inflar la distancia por una coordenada defectuosa.
    if (speedKmh > 160) {
      rejectedJumps++;
      continue;
    }

    activeDuration += gap;
    distanceKm += segmentKm;
    continuousSegments++;
  }

  final accuracyValues = ordered
      .map((item) => item.accuracy)
      .whereType<double>()
      .where((value) => value.isFinite && value >= 0)
      .toList();
  final averageAccuracy = accuracyValues.isEmpty
      ? null
      : accuracyValues.reduce((a, b) => a + b) / accuracyValues.length;

  return _ActiveTrackingMetrics(
    activeDuration: activeDuration,
    distanceKm: distanceKm,
    continuousSegments: continuousSegments,
    pausedGaps: pausedGaps,
    rejectedJumps: rejectedJumps,
    averageAccuracy: averageAccuracy,
  );
}

class _ActiveTrackingMetrics {
  const _ActiveTrackingMetrics({
    required this.activeDuration,
    required this.distanceKm,
    required this.continuousSegments,
    required this.pausedGaps,
    required this.rejectedJumps,
    required this.averageAccuracy,
  });

  final Duration activeDuration;
  final double distanceKm;
  final int continuousSegments;
  final int pausedGaps;
  final int rejectedJumps;
  final double? averageAccuracy;
}

String _historyTimeRange(List<LocationResult> items) {
  if (items.isEmpty) return '--';

  final formatter = DateFormat('HH:mm');
  return '${formatter.format(items.first.capturedAt.toLocal())} - '
      '${formatter.format(items.last.capturedAt.toLocal())}';
}

double _estimateDistanceKm(List<UserLastLocation> items) {
  if (items.length < 2) return 0;
  double total = 0;
  for (var i = 1; i < items.length; i++) {
    total += _haversine(
      items[i - 1].latitude,
      items[i - 1].longitude,
      items[i].latitude,
      items[i].longitude,
    );
  }
  return total;
}

double _haversine(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLon = _degToRad(lon2 - lon1);
  final a =
      _sin2(dLat / 2) +
      _cos(_degToRad(lat1)) * _cos(_degToRad(lat2)) * _sin2(dLon / 2);
  final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
  return r * c;
}

double _degToRad(double deg) => deg * 3.141592653589793 / 180;
double _sin2(double value) {
  final s = _sin(value);
  return s * s;
}

// Tiny math wrappers to avoid importing dart:math with a huge alias in the widget area.
double _sin(double x) => math.sin(x);
double _cos(double x) => math.cos(x);
double _sqrt(double x) => math.sqrt(x);
double _atan2(double y, double x) => math.atan2(y, x);
