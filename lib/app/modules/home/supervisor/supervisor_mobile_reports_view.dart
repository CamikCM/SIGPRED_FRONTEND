import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../data/providers/web_api_provider.dart';
import '../../../utils/app_theme.dart';
import 'supervisor_mobile_ui.dart';

class SupervisorMobileReportsView extends StatefulWidget {
  const SupervisorMobileReportsView({super.key});

  @override
  State<SupervisorMobileReportsView> createState() =>
      _SupervisorMobileReportsViewState();
}

class _SupervisorMobileReportsViewState
    extends State<SupervisorMobileReportsView> {
  final WebApiProvider _api = Get.find<WebApiProvider>();
  DateTime _date = DateTime.now();
  Map<String, dynamic> _data = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.getMap('/reportes/dashboard', {
        'fecha': DateFormat('yyyy-MM-dd').format(_date),
      });
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canNext {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(_date.year, _date.month, _date.day).isBefore(today);
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
    await _load();
  }

  Future<void> _moveDate(int days) async {
    if (days > 0 && !_canNext) return;
    setState(() => _date = _date.add(Duration(days: days)));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _mapOf(_data['resumen']);
    final team = _listOfMaps(_data['rendimiento_visitador']);
    final zones = _listOfMaps(_data['efectividad_zona']);

    final visits = _intOf(summary['visitas_registradas']) ?? 0;
    final effective = _intOf(summary['visitas_efectivas']) ?? 0;
    final ineffective = (visits - effective).clamp(0, visits);
    final effectiveness = visits == 0 ? 0.0 : (effective / visits) * 100;
    final amount = _doubleOf(summary['monto_pedidos']);

    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
          children: [
            const SupervisorPageHero(
              icon: Icons.bar_chart_rounded,
              title: 'Indicadores del equipo',
              subtitle:
                  'Revisa resultados operativos y detecta rápidamente visitadores o zonas que requieren atención.',
              badge: 'REPORTES',
              gradient: SigmaGradients.dark,
            ),
            const SizedBox(height: 12),
            SupervisorDateNavigator(
              date: _date,
              onPrevious: () => _moveDate(-1),
              onNext: _canNext ? () => _moveDate(1) : null,
              onPick: _pickDate,
              label: 'Fecha de análisis',
              compact: true,
            ),
            const SizedBox(height: 12),
            if (_error != null)
              SupervisorErrorCard(message: _error!, onRetry: _load)
            else if (_loading)
              const SigmaCard(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else ...[
              SigmaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SupervisorSectionHeader(
                      title: 'Resumen de ventas',
                      subtitle:
                          'Con pedido = visita efectiva. Sin pedido = visita no efectiva.',
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
                                value: '$visits',
                                color: SigmaColors.secondary,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: SupervisorStatTile(
                                icon: Icons.shopping_bag_outlined,
                                label: 'Con pedido',
                                value: '$effective',
                                color: SigmaColors.success,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: SupervisorStatTile(
                                icon: Icons.remove_shopping_cart_outlined,
                                label: 'Sin pedido',
                                value: '$ineffective',
                                color: SigmaColors.danger,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: SupervisorStatTile(
                                icon: Icons.payments_outlined,
                                label: 'Ventas/pedidos',
                                value: 'Bs ${_money(amount)}',
                                color: SigmaColors.warning,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Efectividad de visitas',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          '${effectiveness.toStringAsFixed(1)}%',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        minHeight: 9,
                        value: (effectiveness / 100).clamp(0.0, 1.0),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                context,
                title: 'Rendimiento del equipo',
                subtitle: 'Compara visitas, pedidos y efectividad.',
                icon: Icons.groups_2_outlined,
                emptyText: 'No hay rendimiento registrado para esta fecha.',
                children: team.map((row) => _teamRow(context, row)).toList(),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                context,
                title: 'Efectividad por zona',
                subtitle:
                    'Identifica dónde conviene revisar cobertura y resultados.',
                icon: Icons.map_outlined,
                emptyText: 'No hay visitas registradas por zona.',
                children: zones.map((row) => _zoneRow(context, row)).toList(),
              ),
              const SizedBox(height: 10),
              Text(
                'La exportación de PDF y el análisis detallado permanecen disponibles en SIGPRED Web.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _teamRow(BuildContext context, Map<String, dynamic> row) {
    final percent = _doubleOf(row['efectividad_porcentaje']);
    final visits = _intOf(row['visitas']) ?? 0;
    final orders = _intOf(row['pedidos']) ?? 0;
    final noOrder = (visits - orders).clamp(0, visits);
    final color = percent >= 70
        ? SigmaColors.success
        : percent >= 50
        ? SigmaColors.warning
        : SigmaColors.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withOpacity(.045),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (row['usu_nombre'] ?? 'Visitador').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              SupervisorStatusPill(
                label: '${percent.toStringAsFixed(1)}%',
                color: color,
                icon: Icons.trending_up_rounded,
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 7,
              color: color,
              backgroundColor: color.withOpacity(.09),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$visits visitas · $orders con pedido · $noOrder sin pedido',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Text(
                'Bs ${_money(row['monto_total'])}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _zoneRow(BuildContext context, Map<String, dynamic> row) {
    final percent = _doubleOf(row['efectividad_porcentaje']);
    final visits = _intOf(row['visitas']) ?? 0;
    final effective = _intOf(row['efectivas']) ?? 0;
    final color = percent >= 70
        ? SigmaColors.success
        : percent >= 50
        ? SigmaColors.warning
        : SigmaColors.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(.22),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: SigmaColors.secondary.withOpacity(.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: SigmaColors.secondary,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (row['zona_nombre'] ?? 'Sin zona').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  '$effective/$visits visitas con pedido',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          SupervisorStatusPill(
            label: '${percent.toStringAsFixed(1)}%',
            color: color,
            icon: Icons.percent_rounded,
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String emptyText,
    required List<Widget> children,
  }) {
    return SigmaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SupervisorSectionHeader(title: title, subtitle: subtitle, icon: icon),
          const SizedBox(height: 11),
          if (children.isEmpty)
            Text(emptyText, style: Theme.of(context).textTheme.bodySmall)
          else
            ...children,
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

List<Map<String, dynamic>> _listOfMaps(dynamic value) {
  if (value is! List) return [];
  return value
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

int? _intOf(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}');
}

double _doubleOf(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

String _money(dynamic value) =>
    NumberFormat('#,##0.00', 'en_US').format(_doubleOf(value));

String _cleanError(Object error) =>
    error.toString().replaceFirst('Exception: ', '').trim();
