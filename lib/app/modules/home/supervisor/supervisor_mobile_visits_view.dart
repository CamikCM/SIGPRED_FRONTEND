import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../data/providers/location_provider.dart';
import '../../../data/providers/web_api_provider.dart';
import '../../../utils/app_theme.dart';
import 'supervisor_mobile_ui.dart';

class SupervisorMobileVisitsView extends StatefulWidget {
  const SupervisorMobileVisitsView({super.key});

  @override
  State<SupervisorMobileVisitsView> createState() =>
      _SupervisorMobileVisitsViewState();
}

class _SupervisorMobileVisitsViewState
    extends State<SupervisorMobileVisitsView> {
  final LocationProvider _locations = Get.find<LocationProvider>();
  final WebApiProvider _api = Get.find<WebApiProvider>();

  final List<Map<String, dynamic>> _users = [];
  final List<Map<String, dynamic>> _visits = [];

  DateTime _date = DateTime.now();
  int? _selectedUserId;
  String _resultFilter = 'all';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialLoad());
  }

  Future<void> _initialLoad() async {
    await _loadUsers();
    await _loadVisits();
  }

  Future<void> _loadUsers() async {
    try {
      final rows = await _locations.getTrackableUsers();
      if (!mounted) return;
      setState(() {
        _users
          ..clear()
          ..addAll(rows);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _cleanError(e));
    }
  }

  Future<void> _loadVisits() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ids = _selectedUserId != null
          ? <int>[_selectedUserId!]
          : _users.map((row) => _intOf(row['id'])).whereType<int>().toList();

      final rows = <Map<String, dynamic>>[];
      if (ids.isNotEmpty) {
        final responses = await Future.wait(
          ids.map(
            (id) => _api.getList('/visitas', {
              'fecha': _dateText(_date),
              'visitador_id': id,
              'per_page': 100,
            }),
          ),
        );

        for (final response in responses) {
          rows.addAll(
            response.whereType<Map>().map(
              (item) => Map<String, dynamic>.from(item),
            ),
          );
        }
      }

      rows.sort(
        (a, b) =>
            _dateOf(b['fecha_inicio']).compareTo(_dateOf(a['fecha_inicio'])),
      );

      if (!mounted) return;
      setState(() {
        _visits
          ..clear()
          ..addAll(rows);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _hasOrder(Map<String, dynamic> visit) =>
      _mapOf(visit['pedido']).isNotEmpty;

  List<Map<String, dynamic>> get _filteredVisits {
    if (_resultFilter == 'effective') {
      return _visits.where(_hasOrder).toList();
    }
    if (_resultFilter == 'ineffective') {
      return _visits.where((row) => !_hasOrder(row)).toList();
    }
    return _visits;
  }

  int get _effectiveCount => _visits.where(_hasOrder).length;
  int get _ineffectiveCount => _visits.length - _effectiveCount;
  double get _effectiveness =>
      _visits.isEmpty ? 0 : (_effectiveCount / _visits.length) * 100;

  bool get _canNext {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = DateTime(_date.year, _date.month, _date.day);
    return current.isBefore(today);
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
    await _loadVisits();
  }

  Future<void> _moveDate(int days) async {
    final candidate = _date.add(Duration(days: days));
    if (days > 0 && !_canNext) return;
    setState(() => _date = candidate);
    await _loadVisits();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _filteredVisits;

    return RefreshIndicator(
      onRefresh: _loadVisits,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 104),
        children: [
          const SupervisorPageHero(
            icon: Icons.fact_check_rounded,
            title: 'Visitas del equipo',
            subtitle:
                'Consulta qué ocurrió en cada punto. Con pedido = visita efectiva; sin pedido = no efectiva.',
            badge: 'RESULTADOS',
          ),
          const SizedBox(height: 12),
          SigmaCard(
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  value: _selectedUserId ?? 0,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Visitador',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: 0,
                      child: Text('Todo mi equipo'),
                    ),
                    ..._users.map((row) {
                      final id = _intOf(row['id']);
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text(
                          (row['name'] ?? 'Visitador').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: _loading
                      ? null
                      : (value) async {
                          setState(
                            () => _selectedUserId = value == 0 ? null : value,
                          );
                          await _loadVisits();
                        },
                ),
                const SizedBox(height: 10),
                SupervisorDateNavigator(
                  date: _date,
                  onPrevious: () => _moveDate(-1),
                  onNext: _canNext ? () => _moveDate(1) : null,
                  onPick: _pickDate,
                  label: 'Fecha de visitas',
                  compact: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null) ...[
            SupervisorErrorCard(message: _error!, onRetry: _loadVisits),
            const SizedBox(height: 12),
          ],
          _summary(context),
          const SizedBox(height: 12),
          _filterChips(),
          const SizedBox(height: 10),
          if (_loading)
            const SigmaCard(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (shown.isEmpty)
            const SupervisorEmptyState(
              icon: Icons.event_busy_outlined,
              title: 'Sin visitas para mostrar',
              message:
                  'Cambia la fecha, el visitador o el resultado seleccionado.',
            )
          else ...[
            SupervisorSectionHeader(
              title: '${shown.length} visita(s)',
              subtitle: 'Toca una tarjeta para revisar el detalle completo.',
            ),
            const SizedBox(height: 8),
            ...shown.map((visit) => _visitCard(context, visit)),
          ],
        ],
      ),
    );
  }

  Widget _summary(BuildContext context) {
    return SigmaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SupervisorSectionHeader(
            title: 'Resultado del día',
            subtitle:
                'La efectividad se determina por la existencia de pedido.',
          ),
          const SizedBox(height: 11),
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
                      icon: Icons.fact_check_outlined,
                      label: 'Realizadas',
                      value: '${_visits.length}',
                      color: SigmaColors.secondary,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: SupervisorStatTile(
                      icon: Icons.shopping_bag_outlined,
                      label: 'Con pedido',
                      value: '$_effectiveCount',
                      color: SigmaColors.success,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: SupervisorStatTile(
                      icon: Icons.remove_shopping_cart_outlined,
                      label: 'Sin pedido',
                      value: '$_ineffectiveCount',
                      color: SigmaColors.danger,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: SupervisorStatTile(
                      icon: Icons.percent_rounded,
                      label: 'Efectividad',
                      value: '${_effectiveness.toStringAsFixed(1)}%',
                      color: _effectiveness >= 70
                          ? SigmaColors.success
                          : SigmaColors.warning,
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

  Widget _filterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('all', 'Todas', Icons.list_alt_rounded),
          const SizedBox(width: 7),
          _filterChip('effective', 'Con pedido', Icons.shopping_bag_outlined),
          const SizedBox(width: 7),
          _filterChip(
            'ineffective',
            'Sin pedido',
            Icons.remove_shopping_cart_outlined,
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label, IconData icon) {
    final selected = _resultFilter == value;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => setState(() => _resultFilter = value),
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? SigmaColors.primary : SigmaColors.muted,
      ),
      label: Text(label),
    );
  }

  Widget _visitCard(BuildContext context, Map<String, dynamic> visit) {
    final user = _mapOf(visit['usuario']);
    final client = _mapOf(visit['cliente']);
    final order = _mapOf(visit['pedido']);
    final effective = order.isNotEmpty;
    final color = effective ? SigmaColors.success : SigmaColors.danger;
    final time = DateFormat(
      'HH:mm',
    ).format(_dateOf(visit['fecha_inicio']).toLocal());

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showVisitDetail(context, visit),
          child: SigmaCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: color.withOpacity(.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    effective
                        ? Icons.shopping_bag_outlined
                        : Icons.remove_shopping_cart_outlined,
                    color: color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              (client['cliente_nombre'] ?? 'Punto de visita')
                                  .toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SupervisorStatusPill(
                            label: effective ? 'Con pedido' : 'Sin pedido',
                            color: color,
                            icon: effective
                                ? Icons.check_circle_outline
                                : Icons.info_outline,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${user['usu_nombre'] ?? 'Visitador'} · $time',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (order.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Pedido: Bs ${_money(order['monto_total'])}',
                          style: const TextStyle(
                            color: SigmaColors.success,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if ((visit['resultado'] ?? visit['motivo'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          (visit['resultado'] ?? visit['motivo']).toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: SigmaColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showVisitDetail(BuildContext context, Map<String, dynamic> visit) {
    final user = _mapOf(visit['usuario']);
    final client = _mapOf(visit['cliente']);
    final zone = _mapOf(client['zona']);
    final order = _mapOf(visit['pedido']);
    final effective = order.isNotEmpty;
    final color = effective ? SigmaColors.success : SigmaColors.danger;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (client['cliente_nombre'] ?? 'Detalle de visita').toString(),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 7),
                SupervisorStatusPill(
                  label: effective
                      ? 'Efectiva · con pedido'
                      : 'No efectiva · sin pedido',
                  color: color,
                  icon: effective
                      ? Icons.shopping_bag_outlined
                      : Icons.remove_shopping_cart_outlined,
                ),
                const SizedBox(height: 18),
                _DetailRow(
                  icon: Icons.badge_outlined,
                  label: 'Visitador',
                  value: (user['usu_nombre'] ?? '—').toString(),
                ),
                _DetailRow(
                  icon: Icons.map_outlined,
                  label: 'Zona',
                  value: (zone['zona_nombre'] ?? '—').toString(),
                ),
                _DetailRow(
                  icon: Icons.schedule_rounded,
                  label: 'Inicio',
                  value: DateFormat(
                    'dd/MM/yyyy HH:mm',
                  ).format(_dateOf(visit['fecha_inicio']).toLocal()),
                ),
                if (visit['duracion_minutos'] != null)
                  _DetailRow(
                    icon: Icons.timelapse_rounded,
                    label: 'Duración registrada',
                    value: '${visit['duracion_minutos']} min',
                  ),
                _DetailRow(
                  icon: Icons.assignment_turned_in_outlined,
                  label: 'Resultado',
                  value: (visit['resultado'] ?? '—').toString(),
                ),
                if ((visit['motivo'] ?? '').toString().trim().isNotEmpty)
                  _DetailRow(
                    icon: Icons.info_outline_rounded,
                    label: 'Motivo',
                    value: visit['motivo'].toString(),
                  ),
                if ((visit['observaciones'] ?? '').toString().trim().isNotEmpty)
                  _DetailRow(
                    icon: Icons.notes_rounded,
                    label: 'Observaciones',
                    value: visit['observaciones'].toString(),
                  ),
                if (visit['cumplimiento_ruta'] != null)
                  _DetailRow(
                    icon: Icons.alt_route_rounded,
                    label: 'Cumplimiento de ruta',
                    value: _boolOf(visit['cumplimiento_ruta']) ? 'Sí' : 'No',
                  ),
                const Divider(height: 26),
                if (order.isNotEmpty) ...[
                  const SupervisorSectionHeader(
                    title: 'Pedido asociado',
                    icon: Icons.shopping_bag_outlined,
                  ),
                  const SizedBox(height: 10),
                  _DetailRow(
                    icon: Icons.payments_outlined,
                    label: 'Monto',
                    value: 'Bs ${_money(order['monto_total'])}',
                  ),
                  if (order['fecha_entrega'] != null)
                    _DetailRow(
                      icon: Icons.local_shipping_outlined,
                      label: 'Entrega',
                      value: order['fecha_entrega'].toString(),
                    ),
                ] else
                  const Text(
                    'Esta visita no generó pedido y, por la regla de efectividad de SIGPRED, se considera no efectiva.',
                    style: TextStyle(height: 1.35),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
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
      padding: const EdgeInsets.only(bottom: 12),
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

bool _boolOf(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase();
  return text == 'true' || text == '1' || text == 'si' || text == 'sí';
}

DateTime _dateOf(dynamic value) {
  if (value is DateTime) return value;
  return DateTime.tryParse((value ?? '').toString().replaceFirst(' ', 'T')) ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

String _dateText(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

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
