import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../data/providers/web_api_provider.dart';
import '../../../utils/app_theme.dart';
import 'supervisor_mobile_ui.dart';

class SupervisorMobilePredictionsView extends StatefulWidget {
  const SupervisorMobilePredictionsView({super.key});

  @override
  State<SupervisorMobilePredictionsView> createState() =>
      _SupervisorMobilePredictionsViewState();
}

class _SupervisorMobilePredictionsViewState
    extends State<SupervisorMobilePredictionsView> {
  final WebApiProvider _api = Get.find<WebApiProvider>();

  static const _models = <_PredictionOption>[
    _PredictionOption(
      value: 'visitador_weekly_sales',
      label: 'Ventas por visitador',
      description: 'Qué venta podría generar cada visitador la próxima semana.',
      icon: Icons.badge_outlined,
      periodLabel: 'próxima semana',
    ),
    _PredictionOption(
      value: 'client_next_sale',
      label: 'Ventas por cliente',
      description:
          'Valor esperado de la próxima compra o pedido de cada cliente.',
      icon: Icons.storefront_outlined,
      periodLabel: 'próxima compra',
    ),
    _PredictionOption(
      value: 'zone_monthly_sales',
      label: 'Ventas por zona',
      description: 'Venta esperada por zona durante el próximo mes.',
      icon: Icons.map_outlined,
      periodLabel: 'próximo mes',
    ),
    _PredictionOption(
      value: 'product_monthly_sales',
      label: 'Ventas por producto',
      description: 'Venta esperada de cada producto durante el próximo mes.',
      icon: Icons.medication_outlined,
      periodLabel: 'próximo mes',
    ),
  ];

  String _selectedModel = _models.first.value;
  Map<String, dynamic> _latest = {};
  bool _loading = true;
  String? _error;

  _PredictionOption get _selectedOption =>
      _models.firstWhere((item) => item.value == _selectedModel);

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
      final data = await _api.getMap('/predicciones/latest', {
        'model_type': _selectedModel,
      });
      if (!mounted) return;
      setState(() => _latest = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final run = _mapOf(_latest['run']);
    final metrics = _mapOf(run['metrics']);
    final predictions = _listOfMaps(_latest['predictions']);
    final sorted = [...predictions]
      ..sort(
        (a, b) => _doubleOf(
          b['predicted_value'],
        ).compareTo(_doubleOf(a['predicted_value'])),
      );

    return Scaffold(
      appBar: AppBar(title: const Text('Predicciones')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
          children: [
            const SupervisorPageHero(
              icon: Icons.auto_graph_rounded,
              title: 'Análisis predictivo',
              subtitle:
                  'Anticipa ventas para apoyar la planificación. SIGPRED utiliza Regresión Lineal Multivariable.',
              badge: 'MACHINE LEARNING',
              gradient: SigmaGradients.dark,
            ),
            const SizedBox(height: 12),
            SigmaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SupervisorSectionHeader(
                    title: '¿Qué deseas pronosticar?',
                    subtitle:
                        'Los cuatro objetivos finales estiman ventas futuras.',
                  ),
                  const SizedBox(height: 10),
                  ..._models.map((option) {
                    final selected = option.value == _selectedModel;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: _loading
                            ? null
                            : () async {
                                if (selected) return;
                                setState(() => _selectedModel = option.value);
                                await _load();
                              },
                        borderRadius: BorderRadius.circular(15),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: selected
                                ? SigmaColors.primary.withOpacity(.065)
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: selected
                                  ? SigmaColors.primary.withOpacity(.45)
                                  : Theme.of(
                                      context,
                                    ).dividerColor.withOpacity(.24),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 39,
                                height: 39,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? SigmaColors.primary.withOpacity(.12)
                                      : SigmaColors.muted.withOpacity(.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  option.icon,
                                  color: selected
                                      ? SigmaColors.primary
                                      : SigmaColors.muted,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      option.label,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      option.description,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                selected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                color: selected
                                    ? SigmaColors.primary
                                    : SigmaColors.muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
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
            else if (run.isEmpty)
              const _EmptyPrediction()
            else ...[
              _businessSummary(context, run, sorted),
              const SizedBox(height: 12),
              _interpretationCard(context),
              const SizedBox(height: 12),
              if (predictions.isEmpty)
                const _EmptyPrediction()
              else ...[
                SupervisorSectionHeader(
                  title: 'Resultados disponibles',
                  subtitle:
                      '${predictions.length} entidad(es) con estimación para ${_selectedOption.periodLabel}.',
                ),
                const SizedBox(height: 8),
                ...sorted.take(15).map((row) => _predictionCard(context, row)),
              ],
              const SizedBox(height: 8),
              _technicalDetails(context, run, metrics, predictions.length),
              const SizedBox(height: 8),
              Text(
                'El pronóstico es apoyo para la decisión; no reemplaza el criterio del Supervisor.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _businessSummary(
    BuildContext context,
    Map<String, dynamic> run,
    List<Map<String, dynamic>> sorted,
  ) {
    final status = (run['status'] ?? '—').toString();
    final ok = status.toLowerCase() == 'ok';
    final generatedAt = _dateOf(run['generated_at']);
    final top = sorted.isEmpty ? <String, dynamic>{} : sorted.first;

    return SigmaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SupervisorSectionHeader(
            title: _selectedOption.label,
            subtitle: _selectedOption.description,
            icon: _selectedOption.icon,
            trailing: SupervisorStatusPill(
              label: ok ? 'Disponible' : status,
              color: ok ? SigmaColors.success : SigmaColors.warning,
              icon: ok ? Icons.check_circle_outline : Icons.info_outline,
            ),
          ),
          const SizedBox(height: 12),
          if (top.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SigmaColors.primary.withOpacity(.055),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SigmaColors.primary.withOpacity(.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mayor venta estimada',
                    style: TextStyle(
                      color: SigmaColors.muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Bs ${_money(top['predicted_value'])}',
                    style: const TextStyle(
                      color: SigmaColors.primary,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    (top['entity_name'] ?? 'Entidad').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          if (generatedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Actualizado: ${DateFormat('dd/MM/yyyy HH:mm').format(generatedAt.toLocal())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if ((run['message'] ?? '').toString().trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              run['message'].toString(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _interpretationCard(BuildContext context) {
    String meaning;
    String use;

    switch (_selectedModel) {
      case 'client_next_sale':
        meaning =
            'SIGPRED estima el valor de la próxima compra de cada cliente según su comportamiento histórico.';
        use =
            'Úsalo para priorizar clientes con mayor venta esperada y preparar mejor las próximas visitas.';
        break;
      case 'zone_monthly_sales':
        meaning =
            'SIGPRED estima cuánto podría venderse en cada zona durante el próximo periodo mensual.';
        use =
            'Úsalo para comparar zonas, revisar cobertura y orientar el acompañamiento del equipo.';
        break;
      case 'product_monthly_sales':
        meaning =
            'SIGPRED estima cuánto podría venderse de cada producto durante el próximo periodo mensual.';
        use =
            'Úsalo para comparar productos y revisar su comportamiento histórico antes de priorizar el seguimiento comercial.';
        break;
      default:
        meaning =
            'SIGPRED estima cuánto podría vender cada visitador durante el próximo periodo semanal.';
        use =
            'Úsalo para detectar diferencias esperadas de rendimiento y revisar oportunamente rutas, clientes y efectividad.';
    }

    return SigmaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SupervisorSectionHeader(
            title: 'Cómo interpretarlo',
            icon: Icons.lightbulb_outline_rounded,
          ),
          const SizedBox(height: 10),
          _ExplanationRow(
            icon: Icons.help_outline_rounded,
            title: '¿Qué significa?',
            text: meaning,
          ),
          const SizedBox(height: 10),
          _ExplanationRow(
            icon: Icons.task_alt_rounded,
            title: '¿Cómo utilizarlo?',
            text: use,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SigmaColors.success.withOpacity(.06),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Text(
              'Regla de efectividad SIGPRED: una visita es efectiva cuando genera un pedido; si se realizó sin pedido, es no efectiva.',
              style: TextStyle(
                fontSize: 11,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _predictionCard(BuildContext context, Map<String, dynamic> row) {
    final value = _doubleOf(row['predicted_value']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SigmaCard(
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: SigmaColors.primary.withOpacity(.09),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(_selectedOption.icon, color: SigmaColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (row['entity_name'] ?? 'Entidad').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Periodo: ${row['target_period'] ?? '—'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Estimado', style: Theme.of(context).textTheme.labelSmall),
                Text(
                  'Bs ${_money(value)}',
                  style: const TextStyle(
                    color: SigmaColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _technicalDetails(
    BuildContext context,
    Map<String, dynamic> run,
    Map<String, dynamic> metrics,
    int count,
  ) {
    return SigmaCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
        title: const Text(
          'Detalles del modelo',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: const Text('Métricas técnicas secundarias'),
        leading: const Icon(Icons.science_outlined, color: SigmaColors.primary),
        childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          _TechnicalRow(
            label: 'Modelo',
            value: 'Regresión Lineal Multivariable',
          ),
          _TechnicalRow(label: 'Predicciones', value: '$count'),
          _TechnicalRow(label: 'MAE', value: _metricValue(metrics['mae'])),
          _TechnicalRow(label: 'RMSE', value: _metricValue(metrics['rmse'])),
          _TechnicalRow(label: 'R²', value: _metricValue(metrics['r2'])),
        ],
      ),
    );
  }
}

class _ExplanationRow extends StatelessWidget {
  const _ExplanationRow({
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: SigmaColors.secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(
                text,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TechnicalRow extends StatelessWidget {
  const _TechnicalRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _EmptyPrediction extends StatelessWidget {
  const _EmptyPrediction();

  @override
  Widget build(BuildContext context) {
    return const SupervisorEmptyState(
      icon: Icons.insights_outlined,
      title: 'Aún no hay información suficiente',
      message:
          'SIGPRED mostrará este pronóstico cuando exista una ejecución válida para el alcance de supervisión.',
    );
  }
}

class _PredictionOption {
  const _PredictionOption({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
    required this.periodLabel,
  });

  final String value;
  final String label;
  final String description;
  final IconData icon;
  final String periodLabel;
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

double _doubleOf(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

DateTime? _dateOf(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString().replaceFirst(' ', 'T'));
}

String _metricValue(dynamic value) =>
    value == null ? '—' : _doubleOf(value).toStringAsFixed(4);

String _money(dynamic value) =>
    NumberFormat('#,##0.00', 'en_US').format(_doubleOf(value));

String _cleanError(Object error) =>
    error.toString().replaceFirst('Exception: ', '').trim();
