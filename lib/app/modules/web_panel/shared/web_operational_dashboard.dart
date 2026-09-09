import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../data/providers/web_api_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../utils/app_theme.dart';
import '../layout/web_panel_shell.dart';
import 'web_widgets.dart';

class WebOperationalDashboard extends StatefulWidget {
  const WebOperationalDashboard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.activeRoute,
    required this.isSupervisor,
    this.showQuickActions = false,
  });

  final String title;
  final String subtitle;
  final String activeRoute;
  final bool isSupervisor;
  final bool showQuickActions;

  @override
  State<WebOperationalDashboard> createState() =>
      _WebOperationalDashboardState();
}

class _WebOperationalDashboardState extends State<WebOperationalDashboard> {
  final DateFormat _apiDate = DateFormat('yyyy-MM-dd');
  final DateFormat _displayDate = DateFormat('dd/MM/yyyy');

  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _payload = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final provider = Get.find<WebApiProvider>();
      final response = await provider.getMap('/reportes/dashboard', {
        'fecha': _apiDate.format(_selectedDate),
      });

      if (!mounted) return;
      setState(() {
        _payload = response;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _cleanError(error);
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (result == null || result == _selectedDate) return;
    setState(() => _selectedDate = result);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _map(_payload['resumen']);
    final zones = _listOfMaps(_payload['efectividad_zona']);
    final visitadores = _listOfMaps(_payload['rendimiento_visitador']);
    final tendencia = _listOfMaps(_payload['tendencia']);

    return WebPanelShell(
      title: widget.title,
      subtitle: widget.isSupervisor
          ? 'Panorama general de la jornada, efectividad, cobertura y alertas para priorizar el seguimiento.'
          : widget.subtitle,
      activeRoute: widget.activeRoute,
      badge: widget.isSupervisor ? 'SUPERVISIÓN' : 'ADMINISTRACIÓN',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilterBar(
            dateLabel: _displayDate.format(_selectedDate),
            loading: _loading,
            onPickDate: _pickDate,
            onPrevious: () => _moveDate(-1),
            onNext: () => _moveDate(1),
            onRefresh: _load,
          ),
          const SizedBox(height: 20),
          if (_error != null)
            _ErrorCard(message: _error!, onRetry: _load)
          else ...[
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _loading && _payload.isEmpty
                  ? const _LoadingCard()
                  : _ExecutiveAdminDashboard(
                      key: ValueKey(_apiDate.format(_selectedDate)),
                      summary: summary,
                      zones: zones,
                      visitadores: visitadores,
                      tendencia: tendencia,
                      selectedDate: _selectedDate,
                      isSupervisor: widget.isSupervisor,
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _moveDate(int days) async {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    await _load();
  }
}

enum _ExecutiveLevel { favorable, attention, critical, neutral }

class _ExecutiveAdminDashboard extends StatelessWidget {
  const _ExecutiveAdminDashboard({
    super.key,
    required this.summary,
    required this.zones,
    required this.visitadores,
    required this.tendencia,
    required this.selectedDate,
    required this.isSupervisor,
  });

  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> zones;
  final List<Map<String, dynamic>> visitadores;
  final List<Map<String, dynamic>> tendencia;
  final DateTime selectedDate;
  final bool isSupervisor;

  @override
  Widget build(BuildContext context) {
    final assessment = _ExecutiveAssessment.from(
      summary: summary,
      zones: zones,
      visitadores: visitadores,
      tendencia: tendencia,
    );

    final plannedPoints = _asInt(summary['puntos_planificados']);
    final attendedPoints = _asInt(summary['puntos_atendidos']);
    final pendingPoints = plannedPoints > attendedPoints
        ? plannedPoints - attendedPoints
        : 0;

    final metrics = isSupervisor
        ? <WebMetric>[
            WebMetric(
              label: 'Visitadores activos',
              value: _integer(summary['visitadores_activos']),
              icon: Icons.groups_2_rounded,
              color: SigmaColors.primary,
            ),
            WebMetric(
              label: 'Jornadas activas',
              value: _integer(summary['jornadas_activas']),
              icon: Icons.timer_rounded,
              color: SigmaColors.secondary,
            ),
            WebMetric(
              label: 'Puntos pendientes',
              value: NumberFormat.decimalPattern('es').format(pendingPoints),
              icon: Icons.pending_actions_rounded,
              color: pendingPoints > 0
                  ? SigmaColors.warning
                  : SigmaColors.success,
            ),
            WebMetric(
              label: 'Visitas realizadas',
              value: _integer(summary['visitas_registradas']),
              icon: Icons.fact_check_rounded,
              color: const Color(0xFF0EA5E9),
            ),
            WebMetric(
              label: 'Visitas con pedido',
              value: _integer(summary['visitas_efectivas']),
              icon: Icons.check_circle_outline_rounded,
              color: SigmaColors.success,
            ),
            WebMetric(
              label: 'Visitas sin pedido',
              value: _integer(summary['visitas_no_efectivas']),
              icon: Icons.report_problem_outlined,
              color: _asInt(summary['visitas_no_efectivas']) > 0
                  ? SigmaColors.warning
                  : SigmaColors.success,
            ),
          ]
        : <WebMetric>[
            WebMetric(
              label: 'Ventas registradas',
              value: _money(summary['monto_pedidos']),
              icon: Icons.payments_rounded,
              color: SigmaColors.primary,
            ),
            WebMetric(
              label: 'Efectividad de visitas',
              value: '${_decimal(summary['efectividad_porcentaje'])}%',
              icon: Icons.ads_click_rounded,
              color: assessment.effectivenessColor,
            ),
            WebMetric(
              label: 'Cobertura general',
              value: plannedPoints <= 0
                  ? 'Sin planificación'
                  : '${NumberFormat("0.#", "es").format(attendedPoints * 100 / plannedPoints)}%',
              icon: Icons.route_rounded,
              color: assessment.complianceColor,
            ),
            WebMetric(
              label: 'Pedidos generados',
              value: _integer(summary['pedidos_generados']),
              icon: Icons.shopping_bag_rounded,
              color: const Color(0xFFEA580C),
            ),
            WebMetric(
              label: 'Visitas realizadas',
              value: _integer(summary['visitas_registradas']),
              icon: Icons.fact_check_rounded,
              color: const Color(0xFF0EA5E9),
            ),
            WebMetric(
              label: 'Visitadores activos',
              value: _integer(summary['visitadores_activos']),
              icon: Icons.groups_2_rounded,
              color: SigmaColors.secondary,
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ExecutiveHero(
          assessment: assessment,
          selectedDate: selectedDate,
          summary: summary,
          isSupervisor: isSupervisor,
        ),
        const SizedBox(height: 18),
        _ExecutiveSectionHeading(
          eyebrow: isSupervisor ? 'CONTROL DEL EQUIPO' : 'LECTURA MACRO',
          title: isSupervisor
              ? 'Indicadores para actuar hoy'
              : 'Indicadores clave para decidir',
          subtitle: isSupervisor
              ? 'Seguimiento operativo de actividad, cobertura y visitas que requieren atención.'
              : 'Vista global de ventas, efectividad de visitas y ejecución de campo.',
        ),
        const SizedBox(height: 12),
        WebMetricGrid(metrics: metrics),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 1080;
            final trend = _TrendCard(items: tendencia);
            final today = _ExecutiveTodayCard(
              summary: summary,
              assessment: assessment,
              isSupervisor: isSupervisor,
            );

            if (stacked) {
              return Column(
                children: [today, const SizedBox(height: 18), trend],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: today),
                const SizedBox(width: 18),
                Expanded(flex: 7, child: trend),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        _ContingencyCard(assessment: assessment, isSupervisor: isSupervisor),
        const SizedBox(height: 20),
        _ExecutiveSectionHeading(
          eyebrow: 'DÓNDE INTERVENIR',
          title: isSupervisor
              ? 'Puntos de atención de supervisión'
              : 'Puntos de atención gerencial',
          subtitle:
              'Prioriza zonas y visitadores que muestran menor conversión en la fecha consultada.',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 980;

            final zoneCard = _AttentionRankingCard(
              title: 'Zonas a revisar',
              icon: Icons.map_outlined,
              emptyMessage:
                  'No hay actividad por zona suficiente para establecer prioridades.',
              items: assessment.zoneAttention,
              primaryLabel: 'Efectividad',
            );

            final visitorCard = _AttentionRankingCard(
              title: 'Visitadores a revisar',
              icon: Icons.groups_2_outlined,
              emptyMessage:
                  'No hay actividad por visitador suficiente para establecer prioridades.',
              items: assessment.visitorAttention,
              primaryLabel: 'Efectividad',
            );

            if (stacked) {
              return Column(
                children: [zoneCard, const SizedBox(height: 18), visitorCard],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: zoneCard),
                const SizedBox(width: 18),
                Expanded(child: visitorCard),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        if (isSupervisor)
          _SupervisorReviewGuide(assessment: assessment)
        else
          _ExecutiveQuickDecisions(),
      ],
    );
  }
}

class _ExecutiveHero extends StatelessWidget {
  const _ExecutiveHero({
    required this.assessment,
    required this.selectedDate,
    required this.summary,
    required this.isSupervisor,
  });

  final _ExecutiveAssessment assessment;
  final DateTime selectedDate;
  final Map<String, dynamic> summary;
  final bool isSupervisor;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.isSameDay(selectedDate, DateTime.now());
    final dateText = _spanishExecutiveDate(selectedDate, includeYear: !today);
    final displayDate = today ? 'Hoy, $dateText' : dateText;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [assessment.levelColor.withOpacity(.11), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: assessment.levelColor.withOpacity(.22)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 820;

          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: assessment.levelColor.withOpacity(.11),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          assessment.levelIcon,
                          size: 16,
                          color: assessment.levelColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          assessment.statusLabel,
                          style: TextStyle(
                            color: assessment.levelColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    displayDate,
                    style: const TextStyle(
                      color: SigmaColors.muted,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                isSupervisor ? 'Panorama de supervisión' : 'Panorama gerencial',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  color: SigmaColors.ink,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                assessment.executiveMessage,
                style: const TextStyle(
                  color: Color(0xFF475467),
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

          final highlights = _ExecutiveHeroHighlights(
            summary: summary,
            assessment: assessment,
            isSupervisor: isSupervisor,
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [intro, const SizedBox(height: 18), highlights],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 7, child: intro),
              const SizedBox(width: 28),
              Expanded(flex: 4, child: highlights),
            ],
          );
        },
      ),
    );
  }
}

class _ExecutiveHeroHighlights extends StatelessWidget {
  const _ExecutiveHeroHighlights({
    required this.summary,
    required this.assessment,
    required this.isSupervisor,
  });

  final Map<String, dynamic> summary;
  final _ExecutiveAssessment assessment;
  final bool isSupervisor;

  @override
  Widget build(BuildContext context) {
    final planned = _asInt(summary['puntos_planificados']);
    final attended = _asInt(summary['puntos_atendidos']);
    final pending = planned > attended ? planned - attended : 0;
    final activeVisitors = _asInt(summary['visitadores_activos']);
    final activeDays = _asInt(summary['jornadas_activas']);
    final nonEffective = _asInt(summary['visitas_no_efectivas']);

    final rows = isSupervisor
        ? <_HeroHighlightData>[
            _HeroHighlightData(
              label: 'Equipo activo',
              value: '$activeVisitors visitadores',
              detail: '$activeDays jornadas continúan activas.',
              icon: Icons.groups_2_outlined,
            ),
            _HeroHighlightData(
              label: 'Puntos pendientes',
              value: '$pending',
              detail: planned <= 0
                  ? 'No hay puntos planificados para la fecha.'
                  : '$attended atendidos de $planned planificados.',
              icon: Icons.pending_actions_outlined,
            ),
            _HeroHighlightData(
              label: 'Visitas sin pedido',
              value: '$nonEffective',
              detail: nonEffective == 0
                  ? 'No hay visitas no efectivas registradas.'
                  : 'Son las primeras visitas que conviene revisar.',
              icon: Icons.report_problem_outlined,
            ),
          ]
        : <_HeroHighlightData>[
            _HeroHighlightData(
              label: 'Ventas del día',
              value: _money(summary['monto_pedidos']),
              detail: 'Monto acumulado de los pedidos registrados.',
              icon: Icons.payments_outlined,
            ),
            _HeroHighlightData(
              label: 'Efectividad de visitas',
              value: '${_decimal(summary['efectividad_porcentaje'])}%',
              detail: 'Visitas con pedido ÷ visitas realizadas.',
              icon: Icons.ads_click_outlined,
            ),
            _HeroHighlightData(
              label: 'Cobertura general',
              value: planned <= 0
                  ? 'Sin planificación'
                  : '${NumberFormat("0.#", "es").format(attended * 100 / planned)}%',
              detail: planned <= 0
                  ? 'No existen puntos planificados para comparar.'
                  : '$attended de $planned puntos planificados atendidos.',
              icon: Icons.route_outlined,
            ),
          ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EBF1)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _HeroValueRow(
              label: rows[i].label,
              value: rows[i].value,
              detail: rows[i].detail,
              icon: rows[i].icon,
            ),
            if (i != rows.length - 1) const Divider(height: 24),
          ],
        ],
      ),
    );
  }
}

class _HeroHighlightData {
  const _HeroHighlightData({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
}

class _HeroValueRow extends StatelessWidget {
  const _HeroValueRow({
    required this.label,
    required this.value,
    required this.icon,
    this.detail,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: SigmaColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: SigmaColors.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              if (detail != null && detail!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  detail!,
                  style: const TextStyle(
                    color: Color(0xFF98A2B3),
                    fontWeight: FontWeight.w600,
                    fontSize: 10.5,
                    height: 1.25,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: SigmaColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExecutiveSectionHeading extends StatelessWidget {
  const _ExecutiveSectionHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: SigmaColors.primary,
            fontSize: 10.5,
            letterSpacing: 1.15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: SigmaColors.ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            color: SigmaColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ExecutiveTodayCard extends StatelessWidget {
  const _ExecutiveTodayCard({
    required this.summary,
    required this.assessment,
    required this.isSupervisor,
  });

  final Map<String, dynamic> summary;
  final _ExecutiveAssessment assessment;
  final bool isSupervisor;

  @override
  Widget build(BuildContext context) {
    final visits = _asInt(summary['visitas_registradas']);
    final effective = _asInt(summary['visitas_efectivas']);
    final nonEffective = _asInt(summary['visitas_no_efectivas']);
    final planned = _asInt(summary['puntos_planificados']);
    final attended = _asInt(summary['puntos_atendidos']);

    return SigmaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isSupervisor ? 'Mi equipo hoy' : 'Situación general del día',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: SigmaColors.ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isSupervisor
                ? 'Actividad operativa del equipo en la fecha consultada.'
                : 'Resumen global antes de profundizar en zonas, personal o reportes.',
            style: const TextStyle(
              color: SigmaColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          _ExecutiveTodayRow(
            icon: Icons.fact_check_outlined,
            label: 'Visitas realizadas',
            value: '$visits',
            detail: '$effective con pedido · $nonEffective sin pedido',
          ),
          const SizedBox(height: 14),
          _ExecutiveTodayRow(
            icon: Icons.route_outlined,
            label: 'Cobertura de ruta',
            value: '$attended / $planned',
            detail: assessment.coverageDetail,
          ),
          const SizedBox(height: 14),
          _ExecutiveTodayRow(
            icon: Icons.shopping_bag_outlined,
            label: 'Pedidos',
            value: _integer(summary['pedidos_generados']),
            detail: 'Cada pedido corresponde a una visita efectiva.',
          ),
          const SizedBox(height: 14),
          _ExecutiveTodayRow(
            icon: Icons.groups_2_outlined,
            label: 'Visitadores activos',
            value: _integer(summary['visitadores_activos']),
            detail:
                '${_integer(summary['jornadas_activas'])} jornadas continúan activas.',
          ),
          const Divider(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                assessment.levelIcon,
                color: assessment.levelColor,
                size: 19,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  assessment.shortManagementReading,
                  style: const TextStyle(
                    color: Color(0xFF475467),
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExecutiveTodayRow extends StatelessWidget {
  const _ExecutiveTodayRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: SigmaColors.primary.withOpacity(.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: SigmaColors.primary),
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
                      label,
                      style: const TextStyle(
                        color: SigmaColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: SigmaColors.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(
                  color: SigmaColors.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContingencyCard extends StatelessWidget {
  const _ContingencyCard({
    required this.assessment,
    required this.isSupervisor,
  });

  final _ExecutiveAssessment assessment;
  final bool isSupervisor;

  @override
  Widget build(BuildContext context) {
    return SigmaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: assessment.levelColor.withOpacity(.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.health_and_safety_outlined,
                  color: assessment.levelColor,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Acciones de contingencia sugeridas',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: SigmaColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSupervisor
                          ? 'Sugerencias automáticas para orientar la revisión del equipo; no sustituyen el criterio del supervisor.'
                          : 'Sugerencias automáticas para orientar la revisión gerencial; no sustituyen el criterio del administrador.',
                      style: const TextStyle(
                        color: SigmaColors.muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Abre cada acción para ver qué detectó SIGPRED, qué revisar y el resultado esperado.',
                      style: TextStyle(
                        color: Color(0xFF667085),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          for (var i = 0; i < assessment.actions.length; i++) ...[
            _ManagementActionTile(number: i + 1, action: assessment.actions[i]),
            if (i != assessment.actions.length - 1) const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }
}

class _ManagementActionTile extends StatelessWidget {
  const _ManagementActionTile({required this.number, required this.action});

  final int number;
  final _ManagementAction action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE8EBF1)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
          childrenPadding: const EdgeInsets.fromLTRB(52, 0, 13, 14),
          leading: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: action.color.withOpacity(.10),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: TextStyle(
                color: action.color,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          title: Text(
            action.title,
            style: const TextStyle(
              color: SigmaColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.detail,
                  style: const TextStyle(
                    color: SigmaColors.muted,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Ver detalle de revisión',
                  style: TextStyle(
                    color: action.color,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          children: [
            _ReviewDetailBlock(
              icon: Icons.search_rounded,
              title: 'Qué detectó SIGPRED',
              text: action.evidence,
              color: action.color,
            ),
            const SizedBox(height: 8),
            _ReviewChecklist(items: action.reviewPoints, color: action.color),
            const SizedBox(height: 8),
            _ReviewDetailBlock(
              icon: Icons.flag_outlined,
              title: 'Resultado esperado',
              text: action.expectedOutcome,
              color: SigmaColors.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewDetailBlock extends StatelessWidget {
  const _ReviewDetailBlock({
    required this.icon,
    required this.title,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withOpacity(.055),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(.13)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: SigmaColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
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

class _ReviewChecklist extends StatelessWidget {
  const _ReviewChecklist({required this.items, required this.color});

  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8EBF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.fact_check_outlined,
                size: 17,
                color: SigmaColors.primary,
              ),
              SizedBox(width: 8),
              Text(
                'Qué revisar',
                style: TextStyle(
                  color: SigmaColors.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
            if (item != items.last) const SizedBox(height: 5),
          ],
        ],
      ),
    );
  }
}

class _AttentionRankingCard extends StatelessWidget {
  const _AttentionRankingCard({
    required this.title,
    required this.icon,
    required this.emptyMessage,
    required this.items,
    required this.primaryLabel,
  });

  final String title;
  final IconData icon;
  final String emptyMessage;
  final List<_AttentionItem> items;
  final String primaryLabel;

  @override
  Widget build(BuildContext context) {
    return SigmaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: SigmaColors.primary, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Ordenado desde la menor efectividad observada.',
            style: TextStyle(
              color: SigmaColors.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 15),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                emptyMessage,
                style: const TextStyle(
                  color: SigmaColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              _AttentionRow(item: items[i], primaryLabel: primaryLabel),
              if (i != items.length - 1) const Divider(height: 17),
            ],
        ],
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.item, required this.primaryLabel});

  final _AttentionItem item;
  final String primaryLabel;

  @override
  Widget build(BuildContext context) {
    final color = item.effectiveness < 40
        ? SigmaColors.danger
        : item.effectiveness < 60
        ? SigmaColors.warning
        : SigmaColors.secondary;

    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: SigmaColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.visits} visitas · ${item.orders} pedidos · ${_money(item.amount)}',
                style: const TextStyle(
                  color: SigmaColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${NumberFormat("0.#", "es").format(item.effectiveness)}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            Text(
              primaryLabel,
              style: const TextStyle(
                color: SigmaColors.muted,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SupervisorReviewGuide extends StatelessWidget {
  const _SupervisorReviewGuide({required this.assessment});

  final _ExecutiveAssessment assessment;

  @override
  Widget build(BuildContext context) {
    const steps = <(IconData, String, String)>[
      (
        Icons.route_outlined,
        '1. Verifica cobertura y jornadas',
        'Confirma puntos pendientes, jornadas activas y rutas con menor avance.',
      ),
      (
        Icons.fact_check_outlined,
        '2. Revisa visitas sin pedido',
        'Ubica motivos repetidos por cliente, zona o visitador antes de intervenir.',
      ),
      (
        Icons.groups_2_outlined,
        '3. Prioriza acompañamiento',
        'Concentra el seguimiento en los casos que aparecen en “Dónde intervenir”.',
      ),
    ];

    return SigmaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ruta de revisión del supervisor',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: SigmaColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            assessment.level == _ExecutiveLevel.favorable
                ? 'La jornada no presenta una alerta principal; utiliza esta secuencia para mantener el control operativo.'
                : 'Utiliza esta secuencia para pasar del panorama general a la causa concreta antes de corregir la operación.',
            style: const TextStyle(
              color: SigmaColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < steps.length; i++) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFBFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE7EAF0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(steps[i].$1, color: SigmaColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].$2,
                          style: const TextStyle(
                            color: SigmaColors.ink,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          steps[i].$3,
                          style: const TextStyle(
                            color: SigmaColors.muted,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (i != steps.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ExecutiveQuickDecisions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const actions = [
      _ExecutiveLink(
        icon: Icons.bar_chart_rounded,
        title: 'Profundizar en reportes',
        subtitle: 'Analiza causas, periodos y comparaciones.',
        route: Routes.webAdminReportes,
      ),
      _ExecutiveLink(
        icon: Icons.auto_graph_rounded,
        title: 'Revisar predicciones',
        subtitle: 'Anticipa ventas por visitador, cliente, zona y producto.',
        route: Routes.webAdminPredicciones,
      ),
      _ExecutiveLink(
        icon: Icons.route_rounded,
        title: 'Revisar planificación',
        subtitle: 'Consulta rutas y cobertura de campo.',
        route: Routes.webAdminRutas,
      ),
    ];

    return SigmaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Siguiente decisión',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: SigmaColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Accesos directos cuando necesites pasar del panorama general al análisis.',
            style: TextStyle(
              color: SigmaColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 860;
              if (stacked) {
                return Column(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      _ExecutiveLinkTile(data: actions[i]),
                      if (i != actions.length - 1) const SizedBox(height: 9),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    Expanded(child: _ExecutiveLinkTile(data: actions[i])),
                    if (i != actions.length - 1) const SizedBox(width: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ExecutiveLink {
  const _ExecutiveLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
}

class _ExecutiveLinkTile extends StatelessWidget {
  const _ExecutiveLinkTile({required this.data});

  final _ExecutiveLink data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFAFBFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Get.toNamed(data.route),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE7EAF0)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: SigmaColors.primary.withOpacity(.08),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(data.icon, color: SigmaColors.primary, size: 19),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: SigmaColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SigmaColors.muted,
                        fontSize: 10.8,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
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

String _spanishExecutiveDate(DateTime value, {required bool includeYear}) {
  const months = <String>[
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  final monthIndex = value.month - 1;
  final month = monthIndex >= 0 && monthIndex < months.length
      ? months[monthIndex]
      : value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');

  if (includeYear) {
    return '$day de $month de ${value.year}';
  }
  return '$day de $month';
}

class _ExecutiveAssessment {
  const _ExecutiveAssessment({
    required this.level,
    required this.executiveMessage,
    required this.shortManagementReading,
    required this.trendComparisonLabel,
    required this.trendComparisonDetail,
    required this.coverageDetail,
    required this.actions,
    required this.zoneAttention,
    required this.visitorAttention,
    required this.effectiveness,
    required this.compliance,
  });

  final _ExecutiveLevel level;
  final String executiveMessage;
  final String shortManagementReading;
  final String trendComparisonLabel;
  final String trendComparisonDetail;
  final String coverageDetail;
  final List<_ManagementAction> actions;
  final List<_AttentionItem> zoneAttention;
  final List<_AttentionItem> visitorAttention;
  final double effectiveness;
  final double compliance;

  Color get levelColor {
    switch (level) {
      case _ExecutiveLevel.favorable:
        return SigmaColors.success;
      case _ExecutiveLevel.attention:
        return SigmaColors.warning;
      case _ExecutiveLevel.critical:
        return SigmaColors.danger;
      case _ExecutiveLevel.neutral:
        return SigmaColors.secondary;
    }
  }

  IconData get levelIcon {
    switch (level) {
      case _ExecutiveLevel.favorable:
        return Icons.check_circle_outline_rounded;
      case _ExecutiveLevel.attention:
        return Icons.warning_amber_rounded;
      case _ExecutiveLevel.critical:
        return Icons.crisis_alert_rounded;
      case _ExecutiveLevel.neutral:
        return Icons.info_outline_rounded;
    }
  }

  String get statusLabel {
    switch (level) {
      case _ExecutiveLevel.favorable:
        return 'SITUACIÓN FAVORABLE';
      case _ExecutiveLevel.attention:
        return 'REQUIERE ATENCIÓN';
      case _ExecutiveLevel.critical:
        return 'ACCIÓN PRIORITARIA';
      case _ExecutiveLevel.neutral:
        return 'ACTIVIDAD INSUFICIENTE';
    }
  }

  Color get effectivenessColor {
    if (effectiveness >= 70) return SigmaColors.success;
    if (effectiveness >= 50) return SigmaColors.warning;
    return SigmaColors.danger;
  }

  Color get complianceColor {
    if (compliance >= 80) return SigmaColors.success;
    if (compliance >= 60) return SigmaColors.warning;
    return SigmaColors.danger;
  }

  static _ExecutiveAssessment from({
    required Map<String, dynamic> summary,
    required List<Map<String, dynamic>> zones,
    required List<Map<String, dynamic>> visitadores,
    required List<Map<String, dynamic>> tendencia,
  }) {
    final visits = _asInt(summary['visitas_registradas']);
    final effective = _asInt(summary['visitas_efectivas']);
    final nonEffective = _asInt(summary['visitas_no_efectivas']);
    final orders = _asInt(summary['pedidos_generados']);
    final planned = _asInt(summary['puntos_planificados']);
    final attended = _asInt(summary['puntos_atendidos']);
    final effectiveness = _asDouble(summary['efectividad_porcentaje']);
    final compliance = _asDouble(summary['cumplimiento_porcentaje']);

    final trendVisits = tendencia.fold<int>(
      0,
      (total, item) => total + _asInt(item['visitas']),
    );
    final trendEffective = tendencia.fold<int>(
      0,
      (total, item) => total + _asInt(item['efectivas']),
    );
    final recentEffectiveness = trendVisits <= 0
        ? 0.0
        : trendEffective * 100 / trendVisits;
    final delta = trendVisits <= 0 ? 0.0 : effectiveness - recentEffectiveness;

    final coverage = planned <= 0 ? 0.0 : attended / planned;

    _ExecutiveLevel level;
    if (planned > 0 && attended == 0) {
      level = _ExecutiveLevel.critical;
    } else if (visits > 0 &&
        trendVisits > 0 &&
        effectiveness < recentEffectiveness - 10) {
      level = _ExecutiveLevel.attention;
    } else if (planned > 0 && coverage < .60) {
      level = _ExecutiveLevel.attention;
    } else if (visits == 0 && planned == 0) {
      level = _ExecutiveLevel.neutral;
    } else {
      level = _ExecutiveLevel.favorable;
    }

    final trendComparisonLabel = trendVisits <= 0
        ? 'Sin comparación'
        : delta.abs() < 1
        ? 'Similar al promedio'
        : delta > 0
        ? '${NumberFormat("0.#", "es").format(delta.abs())} puntos más'
        : '${NumberFormat("0.#", "es").format(delta.abs())} puntos menos';

    final trendComparisonDetail = trendVisits <= 0
        ? 'Aún no hay suficientes visitas recientes para establecer una referencia.'
        : 'Hoy ${NumberFormat("0.#", "es").format(effectiveness)}% · '
              'promedio de los últimos 7 días '
              '${NumberFormat("0.#", "es").format(recentEffectiveness)}%.';

    final executiveMessage = _executiveMessage(
      level: level,
      visits: visits,
      effective: effective,
      nonEffective: nonEffective,
      orders: orders,
      effectiveness: effectiveness,
      recentEffectiveness: recentEffectiveness,
      trendVisits: trendVisits,
      attended: attended,
      planned: planned,
    );

    final actions = <_ManagementAction>[];
    final recentReference = trendVisits <= 0
        ? 'No existe una referencia reciente suficiente.'
        : 'La referencia de los últimos 7 días es '
              '${NumberFormat("0.#", "es").format(recentEffectiveness)}%.';

    if (planned > 0 && attended < planned) {
      final pending = planned - attended;
      actions.add(
        _ManagementAction(
          title: 'Recuperar cobertura pendiente',
          detail:
              'Quedan $pending puntos planificados sin registrar como atendidos.',
          evidence:
              'Se atendieron $attended de $planned puntos planificados '
              '(${NumberFormat("0.#", "es").format(coverage * 100)}% de cobertura).',
          reviewPoints: const [
            'Identificar las rutas que concentran la mayor cantidad de puntos pendientes.',
            'Revisar jornadas activas con poco avance o sin nuevos registros.',
            'Confirmar si existen reprogramaciones, traslados u otras incidencias justificadas.',
          ],
          expectedOutcome:
              'Definir qué puntos todavía pueden recuperarse durante la jornada y cuáles deben reprogramarse con una causa registrada.',
          color: coverage < .60 ? SigmaColors.danger : SigmaColors.warning,
        ),
      );
    }

    if (visits > 0 &&
        nonEffective > 0 &&
        (trendVisits == 0 || effectiveness < recentEffectiveness)) {
      actions.add(
        _ManagementAction(
          title: 'Revisar visitas sin pedido',
          detail:
              'Se registran $nonEffective visitas no efectivas; recuerda que una visita sin pedido se considera no efectiva.',
          evidence:
              '$nonEffective de $visits visitas no generaron pedido. '
              'La efectividad actual es '
              '${NumberFormat("0.#", "es").format(effectiveness)}%. '
              '$recentReference',
          reviewPoints: const [
            'Ubicar clientes o zonas donde se repiten visitas sin pedido.',
            'Revisar los motivos y observaciones registrados por el visitador.',
            'Comparar si la concentración de no efectivas corresponde a un visitador, ruta o tipo de cliente específico.',
          ],
          expectedOutcome:
              'Detectar una causa repetitiva antes de cambiar rutas o prioridades de ventas.',
          color: SigmaColors.warning,
        ),
      );
    }

    if (visits > 0 && orders == 0) {
      actions.add(
        _ManagementAction(
          title: 'Activar seguimiento de ventas',
          detail:
              'Hay visitas registradas, pero ninguna generó pedido durante la fecha consultada.',
          evidence:
              'Se registraron $visits visitas y 0 pedidos; por tanto, la efectividad de visitas del periodo es 0%.',
          reviewPoints: const [
            'Revisar los motivos de no pedido registrados en las visitas.',
            'Identificar clientes visitados repetidamente sin conversión.',
            'Verificar con el equipo si existe una condición de ventas u operativa común que esté afectando la jornada.',
          ],
          expectedOutcome:
              'Definir una acción de seguimiento concreta para los clientes con mayor posibilidad de seguimiento antes de modificar toda la planificación.',
          color: SigmaColors.danger,
        ),
      );
    }

    final zoneAttention = _attentionFromZones(zones);
    final visitorAttention = _attentionFromVisitors(visitadores);

    if (zoneAttention.isNotEmpty) {
      final first = zoneAttention.first;
      if (first.effectiveness + 10 < effectiveness) {
        actions.add(
          _ManagementAction(
            title: 'Intervenir en ${first.name}',
            detail:
                'La zona presenta una efectividad inferior al resultado global del día.',
            evidence:
                '${first.name}: ${first.visits} visitas, ${first.orders} pedidos, '
                '${_money(first.amount)} en ventas y '
                '${NumberFormat("0.#", "es").format(first.effectiveness)}% de efectividad. '
                'Resultado global: '
                '${NumberFormat("0.#", "es").format(effectiveness)}%.',
            reviewPoints: const [
              'Revisar qué clientes de la zona fueron visitados sin generar pedido.',
              'Comparar cobertura planificada frente a puntos realmente atendidos.',
              'Verificar si el bajo resultado se concentra en una ruta o visitador determinado.',
            ],
            expectedOutcome:
                'Precisar si el problema corresponde a cobertura, selección de clientes o efectividad de visitas antes de redistribuir recursos.',
            color: SigmaColors.warning,
          ),
        );
      }
    }

    if (visitorAttention.isNotEmpty) {
      final first = visitorAttention.first;
      if (first.effectiveness + 15 < effectiveness) {
        actions.add(
          _ManagementAction(
            title: 'Dar seguimiento a ${first.name}',
            detail:
                'El visitador presenta una conversión inferior al resultado global del día.',
            evidence:
                '${first.name}: ${first.visits} visitas, ${first.orders} pedidos, '
                '${_money(first.amount)} en ventas y '
                '${NumberFormat("0.#", "es").format(first.effectiveness)}% de efectividad. '
                'Resultado global: '
                '${NumberFormat("0.#", "es").format(effectiveness)}%.',
            reviewPoints: const [
              'Revisar las visitas sin pedido y sus observaciones.',
              'Comparar el tipo y cantidad de clientes atendidos durante la jornada.',
              'Verificar si existen puntos pendientes o diferencias importantes de cobertura en su ruta.',
            ],
            expectedOutcome:
                'Determinar si necesita acompañamiento, ajuste puntual de planificación o seguimiento de ventas específico.',
            color: SigmaColors.warning,
          ),
        );
      }
    }

    if (actions.isEmpty) {
      actions.add(
        _ManagementAction(
          title: 'Mantener el seguimiento y evitar correcciones innecesarias',
          detail:
              'Los indicadores disponibles no muestran una desviación relevante frente a la actividad reciente.',
          evidence:
              'La efectividad actual es '
              '${NumberFormat("0.#", "es").format(effectiveness)}% y el cumplimiento '
              '${NumberFormat("0.#", "es").format(compliance)}%. '
              '$recentReference',
          reviewPoints: const [
            'Continuar observando cobertura, visitas sin pedido y ventas durante la jornada.',
            'Evitar redistribuciones amplias si no existe una desviación persistente.',
            'Usar Reportes o Predicciones cuando sea necesario profundizar una causa o anticipar ventas.',
          ],
          expectedOutcome:
              'Conservar estabilidad operativa y reaccionar únicamente cuando aparezca una desviación respaldada por los datos.',
          color: SigmaColors.success,
        ),
      );
    }

    return _ExecutiveAssessment(
      level: level,
      executiveMessage: executiveMessage,
      shortManagementReading: _shortReading(
        level: level,
        effectiveness: effectiveness,
        recentEffectiveness: recentEffectiveness,
        trendVisits: trendVisits,
        compliance: compliance,
      ),
      trendComparisonLabel: trendComparisonLabel,
      trendComparisonDetail: trendComparisonDetail,
      coverageDetail: planned <= 0
          ? 'No hay puntos planificados para comparar.'
          : '${NumberFormat("0.#", "es").format(coverage * 100)}% de los puntos planificados atendidos.',
      actions: actions.take(3).toList(),
      zoneAttention: zoneAttention.take(5).toList(),
      visitorAttention: visitorAttention.take(5).toList(),
      effectiveness: effectiveness,
      compliance: compliance,
    );
  }
}

String _executiveMessage({
  required _ExecutiveLevel level,
  required int visits,
  required int effective,
  required int nonEffective,
  required int orders,
  required double effectiveness,
  required double recentEffectiveness,
  required int trendVisits,
  required int attended,
  required int planned,
}) {
  if (level == _ExecutiveLevel.neutral) {
    return 'Todavía no existe actividad suficiente para emitir una lectura gerencial del día. Usa esta vista conforme se registren jornadas, visitas y pedidos.';
  }

  if (level == _ExecutiveLevel.critical) {
    return 'La planificación presenta actividad pendiente de ejecución. Antes de evaluar ventas, conviene confirmar jornadas iniciadas, cobertura de rutas y posibles incidencias de campo.';
  }

  if (level == _ExecutiveLevel.attention) {
    if (trendVisits > 0 && effectiveness < recentEffectiveness - 10) {
      return 'La conversión de visitas a pedidos está por debajo del comportamiento reciente. Revisa las visitas no efectivas y concentra el seguimiento en las zonas o visitadores con menor resultado.';
    }
    return 'La cobertura del día avanza por debajo de la referencia operativa. Prioriza los puntos pendientes y revisa rutas que puedan comprometer la efectividad de visitas.';
  }

  return 'La operación se mantiene estable con $visits visitas registradas, $effective efectivas y $orders pedidos. Conviene sostener el seguimiento y profundizar solo donde las tablas de atención muestren desviaciones.';
}

String _shortReading({
  required _ExecutiveLevel level,
  required double effectiveness,
  required double recentEffectiveness,
  required int trendVisits,
  required double compliance,
}) {
  if (level == _ExecutiveLevel.neutral) {
    return 'Aún no hay una base suficiente para comparar el día con la actividad reciente.';
  }

  final comparison = trendVisits <= 0
      ? 'sin una referencia reciente suficiente'
      : effectiveness >= recentEffectiveness
      ? 'en línea o por encima de la conversión reciente'
      : 'por debajo de la conversión reciente';

  return 'La efectividad está ${NumberFormat("0.#", "es").format(effectiveness)}% y el cumplimiento ${NumberFormat("0.#", "es").format(compliance)}%; el resultado se encuentra $comparison.';
}

List<_AttentionItem> _attentionFromZones(List<Map<String, dynamic>> zones) {
  final items = zones
      .where((item) => _asInt(item['visitas']) > 0)
      .map(
        (item) => _AttentionItem(
          name: _string(item['zona_nombre'], 'Sin zona'),
          visits: _asInt(item['visitas']),
          orders: _asInt(item['pedidos']),
          effectiveness: _asDouble(item['efectividad_porcentaje']),
          amount: _asDouble(item['monto_total']),
        ),
      )
      .toList();

  items.sort((a, b) {
    final byEffectiveness = a.effectiveness.compareTo(b.effectiveness);
    if (byEffectiveness != 0) return byEffectiveness;
    return b.visits.compareTo(a.visits);
  });
  return items;
}

List<_AttentionItem> _attentionFromVisitors(
  List<Map<String, dynamic>> visitadores,
) {
  final items = visitadores
      .where((item) => _asInt(item['visitas']) > 0)
      .map(
        (item) => _AttentionItem(
          name: _string(item['usu_nombre'], 'Visitador'),
          visits: _asInt(item['visitas']),
          orders: _asInt(item['pedidos']),
          effectiveness: _asDouble(item['efectividad_porcentaje']),
          amount: _asDouble(item['monto_total']),
        ),
      )
      .toList();

  items.sort((a, b) {
    final byEffectiveness = a.effectiveness.compareTo(b.effectiveness);
    if (byEffectiveness != 0) return byEffectiveness;
    return b.visits.compareTo(a.visits);
  });
  return items;
}

class _AttentionItem {
  const _AttentionItem({
    required this.name,
    required this.visits,
    required this.orders,
    required this.effectiveness,
    required this.amount,
  });

  final String name;
  final int visits;
  final int orders;
  final double effectiveness;
  final double amount;
}

class _ManagementAction {
  const _ManagementAction({
    required this.title,
    required this.detail,
    required this.evidence,
    required this.reviewPoints,
    required this.expectedOutcome,
    required this.color,
  });

  final String title;
  final String detail;
  final String evidence;
  final List<String> reviewPoints;
  final String expectedOutcome;
  final Color color;
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    super.key,
    required this.summary,
    required this.zones,
    required this.visitadores,
    required this.tendencia,
    required this.isSupervisor,
  });

  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> zones;
  final List<Map<String, dynamic>> visitadores;
  final List<Map<String, dynamic>> tendencia;
  final bool isSupervisor;

  @override
  Widget build(BuildContext context) {
    final metrics = <WebMetric>[
      WebMetric(
        label: isSupervisor ? 'Visitadores del equipo' : 'Visitadores activos',
        value: _integer(summary['visitadores_activos']),
        icon: Icons.groups_2_rounded,
        color: SigmaColors.primary,
      ),
      WebMetric(
        label: 'Jornadas activas',
        value: _integer(summary['jornadas_activas']),
        icon: Icons.timer_rounded,
        color: SigmaColors.secondary,
      ),
      WebMetric(
        label: 'Rutas planificadas',
        value: _integer(summary['rutas_planificadas']),
        icon: Icons.route_rounded,
        color: const Color(0xFF7C3AED),
      ),
      WebMetric(
        label: 'Visitas registradas',
        value: _integer(summary['visitas_registradas']),
        icon: Icons.fact_check_rounded,
        color: SigmaColors.warning,
      ),
      WebMetric(
        label: 'Efectividad',
        value: '${_decimal(summary['efectividad_porcentaje'])}%',
        icon: Icons.trending_up_rounded,
        color: SigmaColors.success,
      ),
      WebMetric(
        label: 'Cumplimiento de ruta',
        value: '${_decimal(summary['cumplimiento_porcentaje'])}%',
        icon: Icons.alt_route_rounded,
        color: const Color(0xFF0EA5E9),
      ),
      WebMetric(
        label: 'Pedidos generados',
        value: _integer(summary['pedidos_generados']),
        icon: Icons.shopping_bag_rounded,
        color: const Color(0xFFEA580C),
      ),
      WebMetric(
        label: 'Monto de pedidos',
        value: _money(summary['monto_pedidos']),
        icon: Icons.payments_rounded,
        color: SigmaColors.primaryDark,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WebMetricGrid(metrics: metrics),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 1050;
            if (narrow) {
              return Column(
                children: [
                  _TrendCard(items: tendencia),
                  const SizedBox(height: 20),
                  _DailyStatusCard(summary: summary),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: _TrendCard(items: tendencia)),
                const SizedBox(width: 20),
                Expanded(flex: 4, child: _DailyStatusCard(summary: summary)),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        _LocalTableCard(
          title: 'Efectividad por zona',
          emptyMessage:
              'No existen visitas registradas por zona en la fecha seleccionada.',
          columns: const [
            _LocalColumn('Zona', 230),
            _LocalColumn('Visitas', 100),
            _LocalColumn('Efectivas', 100),
            _LocalColumn('Efectividad', 120),
            _LocalColumn('Pedidos', 100),
            _LocalColumn('Monto', 150),
          ],
          rows: zones
              .map(
                (item) => [
                  _string(item['zona_nombre'], 'Sin zona'),
                  _integer(item['visitas']),
                  _integer(item['efectivas']),
                  '${_decimal(item['efectividad_porcentaje'])}%',
                  _integer(item['pedidos']),
                  _money(item['monto_total']),
                ],
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        _LocalTableCard(
          title: isSupervisor
              ? 'Rendimiento del equipo de campo'
              : 'Rendimiento por visitador médico',
          emptyMessage: 'No existen visitadores disponibles para el reporte.',
          columns: const [
            _LocalColumn('Visitador', 260),
            _LocalColumn('Visitas', 100),
            _LocalColumn('Efectivas', 100),
            _LocalColumn('Efectividad', 120),
            _LocalColumn('Pedidos', 100),
            _LocalColumn('Monto', 150),
          ],
          rows: visitadores
              .map(
                (item) => [
                  _string(item['usu_nombre'], 'Visitador'),
                  _integer(item['visitas']),
                  _integer(item['efectivas']),
                  '${_decimal(item['efectividad_porcentaje'])}%',
                  _integer(item['pedidos']),
                  _money(item['monto_total']),
                ],
              )
              .toList(),
        ),
      ],
    );
  }
}

class _AdminQuickActions extends StatelessWidget {
  const _AdminQuickActions();

  @override
  Widget build(BuildContext context) {
    const actions = [
      _QuickAction(
        label: 'Gestionar usuarios',
        icon: Icons.manage_accounts_outlined,
        route: Routes.webAdminUsuarios,
      ),
      _QuickAction(
        label: 'Planificar rutas',
        icon: Icons.route_outlined,
        route: Routes.webAdminRutas,
      ),
      _QuickAction(
        label: 'Ver visitas',
        icon: Icons.fact_check_outlined,
        route: Routes.webAdminVisitas,
      ),
      _QuickAction(
        label: 'Revisar reportes',
        icon: Icons.bar_chart_rounded,
        route: Routes.webAdminReportes,
      ),
      _QuickAction(
        label: 'Ver predicciones',
        icon: Icons.auto_graph_rounded,
        route: Routes.webAdminPredicciones,
      ),
    ];

    return SigmaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acciones frecuentes',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: SigmaColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Accede directamente a las tareas principales del administrador.',
            style: TextStyle(
              color: SigmaColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: actions.map((action) {
              return OutlinedButton.icon(
                onPressed: () => Get.toNamed(action.route),
                icon: Icon(action.icon, size: 19),
                label: Text(action.label),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  foregroundColor: SigmaColors.ink,
                  side: const BorderSide(color: Color(0xFFE1E5EC)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.dateLabel,
    required this.loading,
    required this.onPickDate,
    required this.onPrevious,
    required this.onNext,
    required this.onRefresh,
  });

  final String dateLabel;
  final bool loading;
  final VoidCallback onPickDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return SigmaCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;

          final dateControls = Wrap(
            spacing: 7,
            runSpacing: 7,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton.outlined(
                  tooltip: 'Día anterior',
                  onPressed: loading ? null : onPrevious,
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                ),
              ),
              SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: loading ? null : onPickDate,
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: Text(dateLabel),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    foregroundColor: SigmaColors.ink,
                    side: const BorderSide(color: Color(0xFFD9DEE8)),
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton.outlined(
                  tooltip: 'Día siguiente',
                  onPressed: loading ? null : onNext,
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                ),
              ),
              SizedBox(
                height: 40,
                child: FilledButton.icon(
                  onPressed: loading ? null : onRefresh,
                  icon: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Actualizar'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    backgroundColor: SigmaColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _DailySummaryTitle(),
                const SizedBox(height: 12),
                dateControls,
              ],
            );
          }

          return Row(
            children: [
              const Expanded(child: _DailySummaryTitle()),
              const SizedBox(width: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: dateControls,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DailySummaryTitle extends StatelessWidget {
  const _DailySummaryTitle();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actividad del día',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: SigmaColors.ink,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Cambia de fecha para revisar el avance operativo.',
          style: TextStyle(
            color: SigmaColors.muted,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final maximum = items.fold<int>(1, (current, item) {
      final value = _asInt(item['visitas']);
      return value > current ? value : current;
    });

    return SigmaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tendencia reciente de efectividad',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const Text(
            'Comparación entre visitas registradas y visitas efectivas.',
            style: TextStyle(
              color: SigmaColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          if (items.isEmpty)
            const SizedBox(
              height: 210,
              child: Center(child: Text('No existen datos para mostrar.')),
            )
          else
            SizedBox(
              height: 235,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: items.map((item) {
                  final visits = _asInt(item['visitas']);
                  final effective = _asInt(item['efectivas']);
                  final totalHeight = visits == 0
                      ? 4.0
                      : 150 * visits / maximum;
                  final effectiveHeight = effective == 0
                      ? 0.0
                      : totalHeight * effective / visits;
                  final date = DateTime.tryParse(_string(item['fecha']));
                  final label = date == null
                      ? '-'
                      : DateFormat('dd/MM').format(date);

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '$effective/$visits',
                            style: const TextStyle(
                              fontSize: 11,
                              color: SigmaColors.muted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 155,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  Container(
                                    width: 30,
                                    height: totalHeight,
                                    decoration: BoxDecoration(
                                      color: SigmaColors.secondary.withOpacity(
                                        .16,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  Container(
                                    width: 30,
                                    height: effectiveHeight,
                                    decoration: BoxDecoration(
                                      color: SigmaColors.primary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: SigmaColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 18,
            children: [
              _Legend(color: SigmaColors.secondary, label: 'Visitas'),
              _Legend(color: SigmaColors.primary, label: 'Efectivas'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyStatusCard extends StatelessWidget {
  const _DailyStatusCard({required this.summary});

  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final visits = _asInt(summary['visitas_registradas']);
    final effective = _asInt(summary['visitas_efectivas']);
    final nonEffective = _asInt(summary['visitas_no_efectivas']);
    final planned = _asInt(summary['puntos_planificados']);
    final attended = _asInt(summary['puntos_atendidos']);

    return SigmaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estado de la jornada',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          _ProgressLine(
            label: 'Visitas efectivas',
            value: effective,
            total: visits,
            color: SigmaColors.success,
          ),
          const SizedBox(height: 18),
          _ProgressLine(
            label: 'Visitas no efectivas',
            value: nonEffective,
            total: visits,
            color: SigmaColors.warning,
          ),
          const SizedBox(height: 18),
          _ProgressLine(
            label: 'Puntos de ruta atendidos',
            value: attended,
            total: planned,
            color: SigmaColors.secondary,
          ),
          const Divider(height: 34),
          _StatusRow(
            icon: Icons.play_circle_fill_rounded,
            label: 'Jornadas iniciadas',
            value: _integer(summary['jornadas_iniciadas']),
          ),
          const SizedBox(height: 12),
          _StatusRow(
            icon: Icons.pending_actions_rounded,
            label: 'Jornadas activas',
            value: _integer(summary['jornadas_activas']),
          ),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = total <= 0
        ? 0.0
        : (value / total).clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '$value / $total',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: progress,
            backgroundColor: color.withOpacity(.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: SigmaColors.primary, size: 22),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: SigmaColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _LocalTableCard extends StatelessWidget {
  const _LocalTableCard({
    required this.title,
    required this.emptyMessage,
    required this.columns,
    required this.rows,
  });

  final String title;
  final String emptyMessage;
  final List<_LocalColumn> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    return SigmaCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: SigmaColors.primary.withOpacity(.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.table_chart_outlined,
                    size: 19,
                    color: SigmaColors.primary,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4F7),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${rows.length} registros',
                    style: const TextStyle(
                      color: Color(0xFF475467),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                emptyMessage,
                style: const TextStyle(
                  color: SigmaColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                horizontalMargin: 14,
                columnSpacing: 24,
                headingRowHeight: 44,
                dataRowMinHeight: 50,
                dataRowMaxHeight: 62,
                dividerThickness: .55,
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFF7F8FC),
                ),
                columns: columns
                    .map(
                      (column) => DataColumn(
                        label: SizedBox(
                          width: column.width,
                          child: Text(
                            column.label,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    )
                    .toList(),
                rows: rows.take(50).toList().asMap().entries.map((entry) {
                  final index = entry.key;
                  final row = entry.value;

                  return DataRow(
                    color: WidgetStatePropertyAll(
                      index.isEven ? Colors.white : const Color(0xFFFBFCFE),
                    ),
                    cells: List.generate(columns.length, (index) {
                      return DataCell(
                        SizedBox(
                          width: columns[index].width,
                          child: Text(
                            index < row.length ? row[index] : '-',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _LocalColumn {
  const _LocalColumn(this.label, this.width);

  final String label;
  final double width;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: SigmaColors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const SigmaCard(
      child: SizedBox(
        height: 280,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: SigmaColors.primary),
              SizedBox(height: 15),
              Text(
                'Cargando indicadores operativos...',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SigmaCard(
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: SigmaColors.danger.withOpacity(.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: SigmaColors.danger,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No se pudieron cargar los indicadores',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(color: SigmaColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _listOfMaps(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

String _integer(dynamic value) => NumberFormat.decimalPattern('es').format(
  value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0,
);

String _decimal(dynamic value) {
  final number = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;
  return NumberFormat('0.##', 'es').format(number);
}

String _money(dynamic value) {
  final number = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;
  return 'Bs ${NumberFormat('#,##0.00', 'es').format(number)}';
}

String _string(dynamic value, [String fallback = '-']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _cleanError(Object error) {
  final message = error.toString();
  return message.startsWith('Exception: ')
      ? message.substring('Exception: '.length)
      : message;
}

class _AdminQuickLinks extends StatelessWidget {
  const _AdminQuickLinks();

  @override
  Widget build(BuildContext context) {
    const items = <_AdminQuickLinkData>[
      _AdminQuickLinkData(
        icon: Icons.manage_accounts_outlined,
        title: 'Gestionar usuarios',
        subtitle: 'Cuentas, roles y personal',
        route: '/web/admin/usuarios',
      ),
      _AdminQuickLinkData(
        icon: Icons.add_business_outlined,
        title: 'Registrar cliente',
        subtitle: 'Datos y ubicación del punto',
        route: '/web/admin/clientes',
      ),
      _AdminQuickLinkData(
        icon: Icons.alt_route_rounded,
        title: 'Planificar ruta',
        subtitle: 'Visitador y puntos de visita',
        route: '/web/admin/rutas',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        if (compact) {
          return Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                SizedBox(
                  width: double.infinity,
                  child: _AdminQuickLink(data: items[i]),
                ),
                if (i != items.length - 1) const SizedBox(height: 9),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              Expanded(child: _AdminQuickLink(data: items[i])),
              if (i != items.length - 1) const SizedBox(width: 11),
            ],
          ],
        );
      },
    );
  }
}

class _AdminQuickLink extends StatelessWidget {
  const _AdminQuickLink({required this.data});
  final _AdminQuickLinkData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Get.offNamed(data.route),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7EBF2)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: SigmaColors.primary.withOpacity(.09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(data.icon, color: SigmaColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.subtitle,
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
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF98A2B3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminQuickLinkData {
  const _AdminQuickLinkData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
}
