import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../../data/providers/web_api_provider.dart';
import '../../../services/auth_service.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/file_exporter.dart';
import '../../../utils/safe_ui.dart';
import '../layout/web_panel_shell.dart';
import 'web_widgets.dart';

class WebPrediccionesView extends StatefulWidget {
  const WebPrediccionesView({
    super.key,
    required this.activeRoute,
    this.title = 'Análisis predictivo',
    this.subtitle =
        'Anticipa ventas futuras por visitador, cliente, zona y producto a partir del historial de ventas de SIGPRED.',
  });

  final String activeRoute;
  final String title;
  final String subtitle;

  @override
  State<WebPrediccionesView> createState() => _WebPrediccionesViewState();
}

class _WebPrediccionesViewState extends State<WebPrediccionesView> {
  static const _models = <_PredictionModelOption>[
    _PredictionModelOption(
      value: 'visitador_weekly_sales',
      label: 'Pronóstico de ventas por visitador',
      description:
          'Estima cuánto podría vender cada visitador durante la próxima semana.',
      icon: Icons.badge_outlined,
      isCurrency: true,
    ),
    _PredictionModelOption(
      value: 'client_next_sale',
      label: 'Pronóstico de ventas por cliente',
      description:
          'Estima el valor esperado de la próxima compra o pedido de cada cliente.',
      icon: Icons.storefront_outlined,
      isCurrency: true,
    ),
    _PredictionModelOption(
      value: 'zone_monthly_sales',
      label: 'Pronóstico de ventas por zona',
      description:
          'Estima el valor de ventas esperado por zona durante el próximo mes.',
      icon: Icons.map_outlined,
      isCurrency: true,
    ),
    _PredictionModelOption(
      value: 'product_monthly_sales',
      label: 'Pronóstico de ventas por producto',
      description:
          'Estima el valor de ventas esperado de cada producto durante el próximo mes.',
      icon: Icons.medication_outlined,
      isCurrency: true,
    ),
  ];

  String _selectedModel = _models.first.value;
  late Future<_PredictionPageData> _future;
  bool _generating = false;

  bool get _isAdmin =>
      Get.find<AuthService>().currentUser.value?.isAdministrador ?? false;

  _PredictionModelOption get _currentModel => _models.firstWhere(
    (item) => item.value == _selectedModel,
    orElse: () => _models.first,
  );

  String get _activeModelValue => _currentModel.value;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PredictionPageData> _load() async {
    final provider = Get.find<WebApiProvider>();
    final responses = await Future.wait<dynamic>([
      provider.getMap('/predicciones/estado'),
      provider.getMap('/predicciones/latest', {
        'model_type': _activeModelValue,
      }),
      provider.getList('/predicciones/ejecuciones', {
        'model_type': _selectedModel,
        'limit': 20,
      }),
      provider.getMap('/predicciones/serie', {'model_type': _activeModelValue}),
    ]);

    return _PredictionPageData(
      status: _map(responses[0]),
      latest: _map(responses[1]),
      runs: _listOfMaps(responses[2]),
      series: _map(responses[3]),
    );
  }

  void _reload() {
    if (!mounted) return;

    setState(() {
      _future = _load();
    });
  }

  Future<void> _generate() async {
    if (!_isAdmin || _generating) return;
    setState(() => _generating = true);

    try {
      final provider = Get.find<WebApiProvider>();
      final response = await provider.post('/predicciones/generar', {
        'model_types': [_activeModelValue],
      });
      final map = _map(response);
      final results = _listOfMaps(map['results']);
      final result = results.isNotEmpty
          ? results.first
          : const <String, dynamic>{};
      final status = (result['status'] ?? '').toString();
      final predictions = _asInt(result['predictions_count']);
      final message = (result['message'] ?? '').toString().trim();

      SafeUi.snackbar(
        'Pronóstico actualizado',
        status == 'ok'
            ? 'Se generaron $predictions resultados para el pronóstico seleccionado.'
            : message.isNotEmpty
            ? message
            : 'El proceso finalizó con estado $status.',
      );
      _reload();
    } catch (error) {
      SafeUi.snackbar('No se pudo generar', _cleanError(error));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebPanelShell(
      title: widget.title,
      subtitle: widget.subtitle,
      activeRoute: widget.activeRoute,
      badge: 'ANÁLISIS PREDICTIVO',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ModelToolbar(
            selected: _activeModelValue,
            options: _models,
            generating: _generating,
            isAdmin: _isAdmin,
            onChanged: (value) {
              if (value == null || value == _selectedModel) return;
              setState(() {
                _selectedModel = value;
                _future = _load();
              });
            },
            onRefresh: _reload,
            onGenerate: _generate,
          ),
          const SizedBox(height: 20),
          FutureBuilder<_PredictionPageData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const _LoadingCard();
              }
              if (snapshot.hasError) {
                return _ErrorCard(
                  message: _cleanError(snapshot.error),
                  onRetry: _reload,
                );
              }

              final data = snapshot.data ?? _PredictionPageData.empty();
              return _PredictionContent(
                key: ValueKey(_currentModel.value),
                data: data,
                model: _currentModel,
                isAdmin: _isAdmin,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PredictionContent extends StatefulWidget {
  const _PredictionContent({
    super.key,
    required this.data,
    required this.model,
    required this.isAdmin,
  });

  final _PredictionPageData data;
  final _PredictionModelOption model;
  final bool isAdmin;

  @override
  State<_PredictionContent> createState() => _PredictionContentState();
}

class _PredictionContentState extends State<_PredictionContent> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minController = TextEditingController();
  final TextEditingController _maxController = TextEditingController();

  String _sort = 'value_desc';
  int? _selectedEntityId;

  @override
  void dispose() {
    _searchController.dispose();
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filteredPredictions(
    List<Map<String, dynamic>> predictions,
  ) {
    final search = _searchController.text.trim().toLowerCase();
    final minimum = _parseDouble(_minController.text);
    final maximum = _parseDouble(_maxController.text);

    final filtered = predictions.where((item) {
      final name = (item['entity_name'] ?? '').toString().toLowerCase();
      final value = _parseDouble(item['predicted_value']) ?? 0;
      if (search.isNotEmpty && !name.contains(search)) return false;
      if (minimum != null && value < minimum) return false;
      if (maximum != null && value > maximum) return false;
      return true;
    }).toList();

    filtered.sort((a, b) {
      final aValue = _parseDouble(a['predicted_value']) ?? 0;
      final bValue = _parseDouble(b['predicted_value']) ?? 0;
      final aName = (a['entity_name'] ?? '').toString().toLowerCase();
      final bName = (b['entity_name'] ?? '').toString().toLowerCase();

      return switch (_sort) {
        'value_asc' => aValue.compareTo(bValue),
        'name_asc' => aName.compareTo(bName),
        'period_asc' => (a['target_period'] ?? '').toString().compareTo(
          (b['target_period'] ?? '').toString(),
        ),
        _ => bValue.compareTo(aValue),
      };
    });

    return filtered;
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _minController.clear();
      _maxController.clear();
      _sort = 'value_desc';
    });
  }

  void _exportCsv(List<Map<String, dynamic>> predictions) {
    if (predictions.isEmpty) {
      SafeUi.snackbar(
        'Exportación',
        'No existen resultados filtrados para exportar.',
      );
      return;
    }

    final rows = <List<String>>[
      <String>[
        'Entidad',
        'Periodo objetivo',
        widget.model.isCurrency ? 'Valor estimado (Bs)' : 'Pedidos estimados',
        widget.model.isCurrency
            ? 'Intervalo inferior (Bs)'
            : 'Intervalo inferior (pedidos)',
        widget.model.isCurrency
            ? 'Intervalo superior (Bs)'
            : 'Intervalo superior (pedidos)',
        'Versión del modelo',
        'Fecha de generación',
      ],
      ...predictions.map(
        (item) => <String>[
          (item['entity_name'] ?? '').toString(),
          (item['target_period'] ?? '').toString(),
          _csvNumber(item['predicted_value']),
          _csvNumber(item['lower_bound']),
          _csvNumber(item['upper_bound']),
          (item['model_version'] ?? '').toString(),
          (item['generated_at'] ?? '').toString(),
        ],
      ),
    ];

    final csv = rows.map((row) => row.map(_escapeCsv).join(';')).join('\r\n');
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());

    FileExporter.downloadText(
      fileName: 'predicciones_${widget.model.value}_$timestamp.csv',
      content: csv,
      mimeType: 'text/csv;charset=utf-8',
    );

    SafeUi.snackbar(
      'Exportación completada',
      'Se exportaron ${predictions.length} predicciones en formato CSV.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = _map(widget.data.status['service']);
    final serviceAvailable = service['available'] == true;
    final run = _map(widget.data.latest['run']);
    final predictions = _listOfMaps(widget.data.latest['predictions']);
    final filteredPredictions = _filteredPredictions(predictions);
    final runStatus = (run['status'] ?? 'sin ejecución').toString();
    final message = (run['message'] ?? '').toString().trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PredictionDecisionSummary(
          model: widget.model,
          run: run,
          predictions: predictions,
        ),
        const SizedBox(height: 16),
        _PredictionInterpretationCard(
          model: widget.model,
          predictions: predictions,
        ),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 16),
          _MessageCard(status: runStatus, message: message),
        ],
        const SizedBox(height: 20),
        _HistoricalPredictionChart(
          model: widget.model,
          seriesData: widget.data.series,
          selectedEntityId: _selectedEntityId,
          onEntityChanged: (value) {
            setState(() => _selectedEntityId = value);
          },
        ),
        const SizedBox(height: 20),
        _PredictionFiltersCard(
          model: widget.model,
          searchController: _searchController,
          minController: _minController,
          maxController: _maxController,
          sort: _sort,
          total: predictions.length,
          filtered: filteredPredictions.length,
          onChanged: () => setState(() {}),
          onSortChanged: (value) {
            if (value == null) return;
            setState(() => _sort = value);
          },
          onClear: _clearFilters,
        ),
        const SizedBox(height: 20),
        _PredictionsTable(
          model: widget.model,
          predictions: filteredPredictions,
          totalPredictions: predictions.length,
          onExport: () => _exportCsv(filteredPredictions),
        ),
        const SizedBox(height: 20),
        _TechnicalDetailsPanel(
          available: serviceAvailable,
          serviceMessage: (service['message'] ?? '').toString(),
          schedule: _scheduleFor(widget.data.status, widget.model.value),
          isAdmin: widget.isAdmin,
          run: run,
          predictions: predictions,
          model: widget.model,
          runs: widget.data.runs,
        ),
      ],
    );
  }
}

class _PredictionDecisionSummary extends StatelessWidget {
  const _PredictionDecisionSummary({
    required this.model,
    required this.run,
    required this.predictions,
  });

  final _PredictionModelOption model;
  final Map<String, dynamic> run;
  final List<Map<String, dynamic>> predictions;

  @override
  Widget build(BuildContext context) {
    final status = (run['status'] ?? '').toString().toLowerCase();
    final metrics = _map(run['metrics']);
    final r2 = _parseDouble(metrics['r2']);
    final testRows = _asInt(run['test_rows']);
    final quality = _qualityBand(r2);
    final qualityLabel = _businessQualityLabel(
      status: status,
      predictionCount: predictions.length,
      testRows: testRows,
      quality: quality,
    );
    final qualityColor = _businessQualityColor(
      status: status,
      predictionCount: predictions.length,
      testRows: testRows,
      quality: quality,
    );

    final top = _highestPrediction(predictions);
    final predictedValue = top == null
        ? 'Sin resultado'
        : _predictionValue(top['predicted_value'], model);
    final entityName = top == null
        ? 'Todavía no hay una estimación disponible.'
        : (top['entity_name'] ?? 'Resultado destacado').toString();
    final period = top == null
        ? '-'
        : (top['target_period'] ?? top['period'] ?? '-').toString();

    return SigmaCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: SigmaColors.primary.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(model.icon, color: SigmaColors.primary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.label,
                      style: const TextStyle(
                        color: SigmaColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      model.description,
                      style: const TextStyle(
                        color: SigmaColors.muted,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: qualityColor.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  qualityLabel,
                  style: TextStyle(
                    color: qualityColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final cards = <Widget>[
                _BusinessResultBox(
                  label: _primaryPredictionLabel(model),
                  value: predictedValue,
                  supporting: entityName,
                  icon: Icons.trending_up_rounded,
                  color: SigmaColors.primary,
                ),
                _BusinessResultBox(
                  label: 'Pronósticos disponibles',
                  value: '${predictions.length}',
                  supporting: predictions.isEmpty
                      ? 'Todavía no existen pronósticos para mostrar.'
                      : 'Entidades con una estimación generada.',
                  icon: Icons.auto_graph_rounded,
                  color: SigmaColors.secondary,
                ),
                _BusinessResultBox(
                  label: 'Periodo previsto',
                  value: period,
                  supporting: 'Periodo asociado al resultado destacado.',
                  icon: Icons.calendar_month_outlined,
                  color: SigmaColors.warning,
                ),
                _BusinessResultBox(
                  label: 'Calidad de validación',
                  value: qualityLabel,
                  supporting: _businessQualityDescription(
                    status: status,
                    predictionCount: predictions.length,
                    testRows: testRows,
                    quality: quality,
                  ),
                  icon: quality.icon,
                  color: qualityColor,
                ),
              ];

              if (compact) {
                return Column(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      cards[i],
                      if (i < cards.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: cards
                    .map(
                      (card) => SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: card,
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 14),
          const Text(
            'Lectura recomendada: observa primero la venta estimada, el periodo objetivo y el rango previsto. La calidad corresponde a la validación histórica del modelo; no es un porcentaje de certeza ni una venta garantizada.',
            style: TextStyle(
              color: SigmaColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionInterpretationCard extends StatelessWidget {
  const _PredictionInterpretationCard({
    required this.model,
    required this.predictions,
  });

  final _PredictionModelOption model;
  final List<Map<String, dynamic>> predictions;

  @override
  Widget build(BuildContext context) {
    final top = _highestPrediction(predictions);
    final entity = top == null
        ? null
        : (top['entity_name'] ?? 'resultado destacado').toString();
    final value = top == null
        ? null
        : _predictionValue(top['predicted_value'], model);

    return SigmaCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: SigmaColors.primary),
              SizedBox(width: 9),
              Text(
                'Cómo interpretar este pronóstico',
                style: TextStyle(
                  color: SigmaColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InterpretationBlock(
            icon: Icons.help_outline_rounded,
            title: '¿Qué estás viendo?',
            text: _predictionMeaning(model, entity, value),
          ),
          const SizedBox(height: 10),
          _InterpretationBlock(
            icon: Icons.analytics_outlined,
            title: '¿De dónde sale esta estimación?',
            text: _predictionInputs(model),
          ),
          const SizedBox(height: 10),
          _InterpretationBlock(
            icon: Icons.task_alt_rounded,
            title: '¿Cómo puedes utilizarla?',
            text: _predictionUse(model),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SigmaColors.success.withValues(alpha: .055),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: SigmaColors.success.withValues(alpha: .14),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: SigmaColors.success,
                  size: 19,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Regla de negocio: CON pedido = visita efectiva; SIN pedido = visita no efectiva. La venta corresponde al monto del pedido. SIGPRED usa los pedidos como información para explicar las ventas, pero los cuatro pronósticos finales estiman ventas futuras.',
                    style: TextStyle(
                      color: SigmaColors.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
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

class _InterpretationBlock extends StatelessWidget {
  const _InterpretationBlock({
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
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: SigmaColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                text,
                style: const TextStyle(
                  color: SigmaColors.muted,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BusinessResultBox extends StatelessWidget {
  const _BusinessResultBox({
    required this.label,
    required this.value,
    required this.supporting,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String supporting;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: .12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: SigmaColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SigmaColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  supporting,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SigmaColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
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

class _TechnicalDetailsPanel extends StatelessWidget {
  const _TechnicalDetailsPanel({
    required this.available,
    required this.serviceMessage,
    required this.schedule,
    required this.isAdmin,
    required this.run,
    required this.predictions,
    required this.model,
    required this.runs,
  });

  final bool available;
  final String serviceMessage;
  final String schedule;
  final bool isAdmin;
  final Map<String, dynamic> run;
  final List<Map<String, dynamic>> predictions;
  final _PredictionModelOption model;
  final List<Map<String, dynamic>> runs;

  @override
  Widget build(BuildContext context) {
    return SigmaCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        leading: const Icon(Icons.science_outlined, color: SigmaColors.primary),
        title: const Text(
          'Ver detalles técnicos',
          style: TextStyle(color: SigmaColors.ink, fontWeight: FontWeight.w900),
        ),
        subtitle: const Text(
          'Métricas de validación, datos utilizados e historial de ejecuciones del modelo.',
          style: TextStyle(
            color: SigmaColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          _IntegrationCard(
            available: available,
            serviceMessage: serviceMessage,
            schedule: schedule,
            isAdmin: isAdmin,
          ),
          const SizedBox(height: 12),
          _QualityAssessmentCard(
            run: run,
            predictions: predictions,
            model: model,
          ),
          const SizedBox(height: 12),
          _RunsTable(runs: runs),
        ],
      ),
    );
  }
}

String _primaryPredictionLabel(_PredictionModelOption model) {
  return switch (model.value) {
    'client_next_sale' => 'Próxima venta estimada más alta',
    _ => 'Mayor venta estimada del periodo',
  };
}

String _predictionMeaning(
  _PredictionModelOption model,
  String? entity,
  String? value,
) {
  if (entity == null || value == null) {
    return 'Todavía no existe un resultado disponible para interpretar. Continúa registrando visitas, pedidos y ventas para aumentar el historial del análisis.';
  }

  return switch (model.value) {
    'visitador_weekly_sales' =>
      'El valor destacado indica que, entre los visitadores con pronóstico disponible, $entity presenta una venta estimada de aproximadamente $value para la próxima semana. Es una estimación futura y no una venta confirmada.',
    'client_next_sale' =>
      'El valor indica que la próxima venta esperada para $entity se estima en aproximadamente $value según su comportamiento histórico. No significa que el cliente ya haya realizado ese pedido.',
    'zone_monthly_sales' =>
      'El valor destacado indica que $entity presenta una venta mensual estimada de aproximadamente $value para el próximo mes. Permite comparar el potencial esperado entre zonas y no representa una venta garantizada.',
    'product_monthly_sales' =>
      'El valor destacado indica que $entity presenta una venta mensual estimada de aproximadamente $value para el próximo mes. Permite comparar el comportamiento esperado entre productos y no representa una venta garantizada.',
    _ =>
      'SIGPRED estima un resultado de $value para $entity en el siguiente periodo.',
  };
}

String _predictionInputs(_PredictionModelOption model) {
  return switch (model.value) {
    'visitador_weekly_sales' =>
      'La Regresión Lineal Multivariable relaciona el historial semanal de ventas del visitador con variables como visitas realizadas, pedidos generados, duración promedio, cumplimiento de ruta y comportamiento de ventas de periodos anteriores.',
    'client_next_sale' =>
      'La Regresión Lineal Multivariable utiliza el historial disponible del cliente: visitas, pedidos, ventas anteriores, duración de atención, cumplimiento y comportamiento temporal para estimar el valor de su siguiente venta.',
    'zone_monthly_sales' =>
      'La Regresión Lineal Multivariable analiza por zona las visitas realizadas, pedidos, duración promedio, cumplimiento y ventas de meses anteriores para proyectar el monto de ventas del siguiente mes.',
    'product_monthly_sales' =>
      'La Regresión Lineal Multivariable analiza por producto los pedidos, unidades vendidas, precio unitario promedio, comportamiento temporal y ventas de meses anteriores para proyectar el monto de ventas del siguiente mes.',
    _ =>
      'SIGPRED utiliza variables históricas de ventas y temporales registradas en el sistema para estimar el siguiente valor de ventas.',
  };
}

String _predictionUse(_PredictionModelOption model) {
  return switch (model.value) {
    'visitador_weekly_sales' =>
      'Compáralo entre visitadores para identificar quiénes tienen una expectativa de venta más baja o alta. Si un resultado requiere atención, revisa su ruta, clientes visitados, pedidos logrados y efectividad de visitas antes de tomar una decisión.',
    'client_next_sale' =>
      'Úsalo para priorizar clientes con mayor valor de compra esperado y organizar próximas visitas. Debe combinarse con frecuencia de atención, historial del cliente y criterio del supervisor; no sustituye una decisión de ventas.',
    'zone_monthly_sales' =>
      'Compáralo entre zonas para decidir dónde reforzar cobertura, rutas o seguimiento. Una zona con menor venta esperada puede revisarse junto con cantidad de visitas, pedidos logrados y cumplimiento antes de redistribuir esfuerzo de ventas.',
    'product_monthly_sales' =>
      'Compáralo entre productos para identificar cuáles presentan mayor o menor venta esperada el próximo mes. Úsalo como apoyo para priorizar seguimiento comercial y revisar su comportamiento histórico antes de tomar decisiones.',
    _ =>
      'Utiliza el resultado como referencia adicional para la planificación y supervisión de ventas.',
  };
}

Map<String, dynamic>? _highestPrediction(
  List<Map<String, dynamic>> predictions,
) {
  Map<String, dynamic>? best;
  double? bestValue;
  for (final item in predictions) {
    final value = _parseDouble(item['predicted_value']);
    if (value == null) continue;
    if (bestValue == null || value > bestValue) {
      best = item;
      bestValue = value;
    }
  }
  return best;
}

String _businessQualityLabel({
  required String status,
  required int predictionCount,
  required int testRows,
  required _QualityBand quality,
}) {
  if (status == 'insufficient_data') return 'Pendiente de datos';
  if (status == 'error') return 'No disponible';
  if (predictionCount == 0) return 'Sin resultados';
  if (testRows < 5) return 'Muestra reducida';
  return quality.shortLabel;
}

Color _businessQualityColor({
  required String status,
  required int predictionCount,
  required int testRows,
  required _QualityBand quality,
}) {
  if (status == 'error') return SigmaColors.danger;
  if (status == 'insufficient_data' || predictionCount == 0 || testRows < 5) {
    return SigmaColors.warning;
  }
  return quality.color;
}

String _businessQualityDescription({
  required String status,
  required int predictionCount,
  required int testRows,
  required _QualityBand quality,
}) {
  if (status == 'insufficient_data') {
    return 'Aún falta historial para entrenar y validar el modelo.';
  }
  if (status == 'error') {
    return 'La última ejecución no pudo generar un análisis utilizable.';
  }
  if (predictionCount == 0) {
    return 'La ejecución actual no produjo estimaciones.';
  }
  if (testRows < 5) {
    return 'La muestra de prueba todavía es pequeña; úsalo como referencia.';
  }
  if (quality.shortLabel == 'Alta' || quality.shortLabel == 'Buena') {
    return 'La validación histórica es favorable. El resultado puede apoyar la planificación, pero no representa un porcentaje de certeza.';
  }
  if (quality.shortLabel == 'Moderada') {
    return 'La validación histórica es intermedia. Úsalo como apoyo y contrástalo con resultados de ventas reales antes de decidir.';
  }
  if (quality.shortLabel == 'Referencial') {
    return 'Úsalo como referencia exploratoria mientras se acumula más historial.';
  }
  if (quality.shortLabel == 'Insuficiente') {
    return 'No conviene basar decisiones en este resultado hasta mejorar la validación.';
  }
  return 'Todavía no existe una evaluación suficiente para clasificar este análisis.';
}

class _ModelToolbar extends StatelessWidget {
  const _ModelToolbar({
    required this.selected,
    required this.options,
    required this.generating,
    required this.isAdmin,
    required this.onChanged,
    required this.onRefresh,
    required this.onGenerate,
  });

  final String selected;
  final List<_PredictionModelOption> options;
  final bool generating;
  final bool isAdmin;
  final ValueChanged<String?> onChanged;
  final VoidCallback onRefresh;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return SigmaCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Qué deseas pronosticar?',
            style: TextStyle(
              color: SigmaColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Selecciona el nivel de análisis. Los cuatro pronósticos estiman VENTAS futuras en Bs. Los pedidos y sus detalles se utilizan como información histórica y variables explicativas del análisis.',
            style: TextStyle(
              color: SigmaColors.muted,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final fourColumns = constraints.maxWidth >= 1280;
              final width = compact
                  ? constraints.maxWidth
                  : fourColumns
                  ? (constraints.maxWidth - 36) / 4
                  : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: options
                    .map(
                      (option) => SizedBox(
                        width: width,
                        child: _ModelChoiceCard(
                          option: option,
                          selected: option.value == selected,
                          onTap: () => onChanged(option.value),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final message = Text(
                isAdmin
                    ? 'Genera solo el pronóstico seleccionado. El resultado se recalcula con el historial disponible y se conserva como una nueva ejecución.'
                    : 'Modo consulta: puedes revisar los resultados disponibles sin modificar el modelo.',
                style: const TextStyle(
                  color: SigmaColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Actualizar'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                  ),
                  if (isAdmin)
                    FilledButton.icon(
                      onPressed: generating ? null : onGenerate,
                      icon: generating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_arrow_rounded, size: 19),
                      label: Text(
                        generating ? 'Generando...' : 'Generar pronóstico',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        backgroundColor: SigmaColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                      ),
                    ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [message, const SizedBox(height: 10), actions],
                );
              }

              return Row(
                children: [
                  Expanded(child: message),
                  const SizedBox(width: 10),
                  actions,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ModelChoiceCard extends StatelessWidget {
  const _ModelChoiceCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _PredictionModelOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? SigmaColors.primary.withValues(alpha: .065)
          : const Color(0xFFFBFCFE),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? SigmaColors.primary : const Color(0xFFE5EAF1),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (selected ? SigmaColors.primary : SigmaColors.muted)
                      .withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  option.icon,
                  color: selected ? SigmaColors.primary : SigmaColors.muted,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: const TextStyle(
                        color: SigmaColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      option.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SigmaColors.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? SigmaColors.primary : SigmaColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntegrationCard extends StatelessWidget {
  const _IntegrationCard({
    required this.available,
    required this.serviceMessage,
    required this.schedule,
    required this.isAdmin,
  });

  final bool available;
  final String serviceMessage;
  final String schedule;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final color = available ? SigmaColors.success : SigmaColors.danger;
    return SigmaCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              available ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              color: color,
              size: 23,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  available
                      ? 'Servicio predictivo disponible'
                      : 'Servicio predictivo no disponible',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: SigmaColors.ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  available
                      ? 'El servicio está listo. Ejecución programada: $schedule.'
                      : serviceMessage.isNotEmpty
                      ? serviceMessage
                      : 'El servicio de predicciones no está disponible en este momento.',
                  style: const TextStyle(
                    color: SigmaColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SigmaPill(
            label: isAdmin ? 'Administrador' : 'Solo consulta',
            icon: isAdmin
                ? Icons.admin_panel_settings_outlined
                : Icons.visibility_outlined,
            color: isAdmin ? SigmaColors.primary : SigmaColors.secondary,
          ),
        ],
      ),
    );
  }
}

class _QualityAssessmentCard extends StatelessWidget {
  const _QualityAssessmentCard({
    required this.run,
    required this.predictions,
    required this.model,
  });

  final Map<String, dynamic> run;
  final List<Map<String, dynamic>> predictions;
  final _PredictionModelOption model;

  @override
  Widget build(BuildContext context) {
    final status = (run['status'] ?? '').toString().toLowerCase();
    final metrics = _map(run['metrics']);
    final r2 = _parseDouble(metrics['r2']);
    final mae = _parseDouble(metrics['mae']);
    final rmse = _parseDouble(metrics['rmse']);
    final testRows = _asInt(run['test_rows']);

    late final String title;
    late final String description;
    late final Color color;
    late final IconData icon;

    if (status == 'insufficient_data') {
      title = 'Modelo pendiente de más datos';
      description =
          'Todavía no existe el historial mínimo requerido para entrenar y validar este modelo.';
      color = SigmaColors.warning;
      icon = Icons.hourglass_bottom_rounded;
    } else if (status == 'error') {
      title = 'Modelo con error';
      description =
          'Revise el estado del servicio predictivo y el detalle de la última ejecución.';
      color = SigmaColors.danger;
      icon = Icons.error_outline_rounded;
    } else if (predictions.isEmpty) {
      title = 'Aún no hay pronósticos disponibles';
      description =
          'El entrenamiento terminó, pero no produjo predicciones para las entidades disponibles.';
      color = SigmaColors.warning;
      icon = Icons.info_outline_rounded;
    } else if (r2 == null) {
      title = 'Sin evaluación estadística';
      description =
          'La ejecución produjo resultados, pero no existe un valor R² disponible para valorar su capacidad explicativa.';
      color = SigmaColors.muted;
      icon = Icons.analytics_outlined;
    } else if (testRows < 5) {
      title = 'Muestra de prueba reducida';
      description =
          'El modelo funciona, pero el conjunto de prueba todavía es demasiado pequeño para clasificar su calidad con suficiente respaldo.';
      color = SigmaColors.warning;
      icon = Icons.science_outlined;
    } else {
      final quality = _qualityBand(r2);
      title = quality.label;
      description = quality.description;
      color = quality.color;
      icon = quality.icon;
    }

    return SigmaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        color: SigmaColors.muted,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (status == 'ok' && predictions.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QualityMetricChip(
                  label: 'R²',
                  value: _metric(r2),
                  color: color,
                ),
                _QualityMetricChip(
                  label: 'MAE',
                  value: _metricWithUnit(mae, model),
                  color: SigmaColors.warning,
                ),
                _QualityMetricChip(
                  label: 'RMSE',
                  value: _metricWithUnit(rmse, model),
                  color: SigmaColors.primary,
                ),
                _QualityMetricChip(
                  label: 'Prueba',
                  value: '$testRows filas',
                  color: SigmaColors.secondary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'MAE representa el error absoluto promedio; RMSE penaliza con mayor fuerza los errores grandes; R² indica cuánto de la variación observada explica el modelo en el conjunto de prueba.',
              style: TextStyle(
                color: SigmaColors.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'La clasificación corresponde a la última validación disponible y debe utilizarse como apoyo a la planificación, junto con criterio de ventas y nueva información histórica.',
              style: TextStyle(
                color: SigmaColors.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QualityMetricChip extends StatelessWidget {
  const _QualityMetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: .14)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: SigmaColors.ink,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _HistoricalPredictionChart extends StatelessWidget {
  const _HistoricalPredictionChart({
    required this.model,
    required this.seriesData,
    required this.selectedEntityId,
    required this.onEntityChanged,
  });

  final _PredictionModelOption model;
  final Map<String, dynamic> seriesData;
  final int? selectedEntityId;
  final ValueChanged<int?> onEntityChanged;

  @override
  Widget build(BuildContext context) {
    final entities = _listOfMaps(seriesData['entities']);
    final series = _listOfMaps(seriesData['series']);
    final predictions = _listOfMaps(seriesData['predictions']);

    final availableIds = entities
        .map((item) => _asInt(item['entity_id']))
        .toSet();
    final effectiveEntityId = availableIds.contains(selectedEntityId)
        ? selectedEntityId
        : entities.isNotEmpty
        ? _asInt(entities.first['entity_id'])
        : null;

    final actual =
        series
            .where((item) => _asInt(item['entity_id']) == effectiveEntityId)
            .toList()
          ..sort(
            (a, b) => (a['period'] ?? '').toString().compareTo(
              (b['period'] ?? '').toString(),
            ),
          );

    final prediction = _firstMapWhere(
      predictions,
      (item) => _asInt(item['entity_id']) == effectiveEntityId,
    );

    return SigmaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 360,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Histórico frente a predicción',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Compara el comportamiento real de periodos anteriores con la estimación generada para el siguiente periodo de la entidad seleccionada.',
                      style: const TextStyle(
                        color: SigmaColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 340,
                child: DropdownButtonFormField<int>(
                  isExpanded: true,
                  key: ValueKey('${model.value}-$effectiveEntityId'),
                  initialValue: effectiveEntityId,
                  decoration: const InputDecoration(
                    labelText: 'Entidad para la gráfica',
                    prefixIcon: Icon(Icons.person_search_outlined),
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  items: entities
                      .map(
                        (item) => DropdownMenuItem<int>(
                          value: _asInt(item['entity_id']),
                          child: Text(
                            (item['entity_name'] ?? 'Sin nombre').toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: entities.isEmpty ? null : onEntityChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (effectiveEntityId == null || actual.isEmpty)
            const _ChartEmptyState(
              message:
                  'No existen periodos históricos disponibles para construir la gráfica.',
            )
          else
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 300,
                  child: CustomPaint(
                    painter: _PredictionChartPainter(
                      actual: actual,
                      prediction: prediction,
                      primary: SigmaColors.secondary,
                      predictionColor: SigmaColors.primary,
                      gridColor: Theme.of(context).dividerColor,
                      textColor: SigmaColors.muted,
                      isCurrency: model.isCurrency,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 22,
                  runSpacing: 10,
                  children: const [
                    _ChartLegend(
                      color: SigmaColors.secondary,
                      label: 'Valor histórico real',
                    ),
                    _ChartLegend(
                      color: SigmaColors.primary,
                      label: 'Predicción del siguiente periodo',
                    ),
                    _ChartLegend(
                      color: SigmaColors.warning,
                      label: 'Intervalo estimado',
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: SigmaColors.surface,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: SigmaColors.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
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

class _PredictionChartPainter extends CustomPainter {
  const _PredictionChartPainter({
    required this.actual,
    required this.prediction,
    required this.primary,
    required this.predictionColor,
    required this.gridColor,
    required this.textColor,
    required this.isCurrency,
  });

  final List<Map<String, dynamic>> actual;
  final Map<String, dynamic>? prediction;
  final Color primary;
  final Color predictionColor;
  final Color gridColor;
  final Color textColor;
  final bool isCurrency;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 62.0;
    const top = 18.0;
    const right = 26.0;
    const bottom = 48.0;
    final chartWidth = math.max(1.0, size.width - left - right);
    final chartHeight = math.max(1.0, size.height - top - bottom);
    final chartRect = Rect.fromLTWH(left, top, chartWidth, chartHeight);

    final actualValues = actual
        .map((item) => _parseDouble(item['actual_value']) ?? 0)
        .toList();
    final predicted = _parseDouble(prediction?['predicted_value']);
    final lower = _parseDouble(prediction?['lower_bound']);
    final upper = _parseDouble(prediction?['upper_bound']);
    final allValues = <double>[
      ...actualValues,
      if (predicted != null) predicted,
      if (lower != null) lower,
      if (upper != null) upper,
    ];

    if (allValues.isEmpty) return;

    var minValue = allValues.reduce(math.min);
    var maxValue = allValues.reduce(math.max);
    if ((maxValue - minValue).abs() < .001) {
      maxValue += 1;
      minValue = math.max(0.0, minValue - 1);
    }
    final padding = (maxValue - minValue) * .12;
    maxValue += padding;
    minValue = math.max(0.0, minValue - padding);

    double yFor(double value) {
      final ratio = (value - minValue) / (maxValue - minValue);
      return chartRect.bottom - ratio * chartHeight;
    }

    final totalPoints = actual.length + (prediction == null ? 0 : 1);
    double xFor(int index) {
      if (totalPoints <= 1) return chartRect.center.dx;
      return chartRect.left + (chartWidth * index / (totalPoints - 1));
    }

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: .75)
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = chartRect.top + chartHeight * i / 4;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
      final value = maxValue - (maxValue - minValue) * i / 4;
      _paintText(
        canvas,
        isCurrency
            ? 'Bs ${NumberFormat.compact(locale: 'es').format(value)}'
            : '${NumberFormat.compact(locale: 'es').format(value)} ped.',
        Offset(0, y - 8),
        width: left - 8,
        align: TextAlign.right,
        color: textColor,
        fontSize: 10,
      );
    }

    final axisPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.2;
    canvas.drawLine(chartRect.bottomLeft, chartRect.bottomRight, axisPaint);
    canvas.drawLine(chartRect.topLeft, chartRect.bottomLeft, axisPaint);

    if (actual.isNotEmpty) {
      final linePaint = Paint()
        ..color = primary
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      for (var i = 0; i < actualValues.length; i++) {
        final point = Offset(xFor(i), yFor(actualValues[i]));
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path, linePaint);

      final pointPaint = Paint()..color = primary;
      for (var i = 0; i < actualValues.length; i++) {
        canvas.drawCircle(
          Offset(xFor(i), yFor(actualValues[i])),
          4.5,
          pointPaint,
        );
      }
    }

    if (prediction != null && predicted != null) {
      final predictionIndex = totalPoints - 1;
      final predictionX = xFor(predictionIndex);
      if (actualValues.isNotEmpty) {
        final dashedPaint = Paint()
          ..color = predictionColor.withValues(alpha: .6)
          ..strokeWidth = 2;
        _drawDashedLine(
          canvas,
          Offset(xFor(actualValues.length - 1), yFor(actualValues.last)),
          Offset(predictionX, yFor(predicted)),
          dashedPaint,
        );
      }

      if (lower != null && upper != null) {
        final intervalPaint = Paint()
          ..color = SigmaColors.warning
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(predictionX, yFor(lower)),
          Offset(predictionX, yFor(upper)),
          intervalPaint,
        );
        canvas.drawLine(
          Offset(predictionX - 7, yFor(lower)),
          Offset(predictionX + 7, yFor(lower)),
          intervalPaint,
        );
        canvas.drawLine(
          Offset(predictionX - 7, yFor(upper)),
          Offset(predictionX + 7, yFor(upper)),
          intervalPaint,
        );
      }

      final predictionPaint = Paint()..color = predictionColor;
      canvas.drawCircle(
        Offset(predictionX, yFor(predicted)),
        7,
        predictionPaint,
      );
      canvas.drawCircle(
        Offset(predictionX, yFor(predicted)),
        3,
        Paint()..color = Colors.white,
      );
    }

    if (actual.isNotEmpty) {
      _paintText(
        canvas,
        _shortDate(actual.first['period']),
        Offset(chartRect.left - 28, chartRect.bottom + 12),
        width: 70,
        align: TextAlign.center,
        color: textColor,
        fontSize: 10,
      );
      if (actual.length > 1) {
        _paintText(
          canvas,
          _shortDate(actual.last['period']),
          Offset(xFor(actual.length - 1) - 35, chartRect.bottom + 12),
          width: 70,
          align: TextAlign.center,
          color: textColor,
          fontSize: 10,
        );
      }
    }

    if (prediction != null) {
      _paintText(
        canvas,
        'Pred. ${_shortDate(prediction?['target_period'])}',
        Offset(xFor(totalPoints - 1) - 42, chartRect.bottom + 12),
        width: 84,
        align: TextAlign.center,
        color: predictionColor,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 7.0;
    const gap = 5.0;
    final distance = (end - start).distance;
    if (distance <= 0) return;
    final direction = (end - start) / distance;
    var traveled = 0.0;
    while (traveled < distance) {
      final segmentEnd = math.min(traveled + dash, distance);
      canvas.drawLine(
        start + direction * traveled,
        start + direction * segmentEnd,
        paint,
      );
      traveled += dash + gap;
    }
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset offset, {
    required double width,
    required TextAlign align,
    required Color color,
    required double fontSize,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _PredictionChartPainter oldDelegate) => true;
}

class _PredictionFiltersCard extends StatelessWidget {
  const _PredictionFiltersCard({
    required this.model,
    required this.searchController,
    required this.minController,
    required this.maxController,
    required this.sort,
    required this.total,
    required this.filtered,
    required this.onChanged,
    required this.onSortChanged,
    required this.onClear,
  });

  final _PredictionModelOption model;
  final TextEditingController searchController;
  final TextEditingController minController;
  final TextEditingController maxController;
  final String sort;
  final int total;
  final int filtered;
  final VoidCallback onChanged;
  final ValueChanged<String?> onSortChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SigmaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Filtros de resultados',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              SigmaPill(
                label: '$filtered de $total',
                icon: Icons.filter_alt_outlined,
                color: SigmaColors.secondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: searchController,
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(
                    labelText: 'Buscar entidad',
                    prefixIcon: Icon(Icons.search_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: minController,
                  onChanged: (_) => onChanged(),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: model.isCurrency
                        ? 'Valor mínimo'
                        : 'Pedidos mínimos',
                    prefixText: model.isCurrency ? 'Bs ' : null,
                    suffixText: model.isCurrency ? null : 'ped.',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: maxController,
                  onChanged: (_) => onChanged(),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: model.isCurrency
                        ? 'Valor máximo'
                        : 'Pedidos máximos',
                    prefixText: model.isCurrency ? 'Bs ' : null,
                    suffixText: model.isCurrency ? null : 'ped.',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: 245,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey(sort),
                  initialValue: sort,
                  decoration: const InputDecoration(
                    labelText: 'Ordenar por',
                    prefixIcon: Icon(Icons.sort_rounded),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'value_desc',
                      child: Text(
                        'Mayor valor primero',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'value_asc',
                      child: Text(
                        'Menor valor primero',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'name_asc',
                      child: Text(
                        'Nombre A–Z',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'period_asc',
                      child: Text(
                        'Periodo más próximo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: onSortChanged,
                ),
              ),
              OutlinedButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Limpiar'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 12,
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

class _PredictionsTable extends StatelessWidget {
  const _PredictionsTable({
    required this.model,
    required this.predictions,
    required this.totalPredictions,
    required this.onExport,
  });

  final _PredictionModelOption model;
  final List<Map<String, dynamic>> predictions;
  final int totalPredictions;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return SigmaCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: SigmaColors.primary.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(model.icon, color: SigmaColors.primary),
                ),
                SizedBox(
                  width: 520,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        model.description,
                        style: const TextStyle(
                          color: SigmaColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
                    border: Border.all(color: const Color(0xFFE4E7EC)),
                  ),
                  child: Text(
                    '${predictions.length} de $totalPredictions resultados',
                    style: const TextStyle(
                      color: Color(0xFF475467),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: predictions.isEmpty ? null : onExport,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Exportar CSV'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (predictions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No existen predicciones que coincidan con los filtros actuales.',
                style: TextStyle(
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
                headingTextStyle: const TextStyle(
                  color: Color(0xFF475467),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
                dataTextStyle: const TextStyle(
                  color: SigmaColors.ink,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                columns: const [
                  DataColumn(label: Text('N°')),
                  DataColumn(label: Text('Entidad')),
                  DataColumn(label: Text('Periodo objetivo')),
                  DataColumn(label: Text('Valor estimado')),
                  DataColumn(label: Text('Rango estimado desde')),
                  DataColumn(label: Text('Rango estimado hasta')),
                  DataColumn(label: Text('Versión')),
                ],
                rows: predictions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;

                  return DataRow(
                    color: WidgetStatePropertyAll(
                      index.isEven ? Colors.white : const Color(0xFFFBFCFE),
                    ),
                    cells: [
                      DataCell(
                        Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: SigmaColors.muted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 260,
                          child: Text(
                            (item['entity_name'] ?? 'Sin nombre').toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(_date(item['target_period']))),
                      DataCell(
                        Text(_predictionValue(item['predicted_value'], model)),
                      ),
                      DataCell(
                        Text(_predictionValue(item['lower_bound'], model)),
                      ),
                      DataCell(
                        Text(_predictionValue(item['upper_bound'], model)),
                      ),
                      DataCell(Text((item['model_version'] ?? '—').toString())),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _RunsTable extends StatelessWidget {
  const _RunsTable({required this.runs});
  final List<Map<String, dynamic>> runs;

  @override
  Widget build(BuildContext context) {
    return SigmaCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: SigmaColors.secondary.withOpacity(.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    size: 19,
                    color: SigmaColors.secondary,
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Historial de ejecuciones',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Resultado de los últimos entrenamientos del modelo seleccionado.',
                        style: TextStyle(
                          color: SigmaColors.muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
                    '${runs.length} ejecuciones',
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
          if (runs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No se registraron ejecuciones del modelo seleccionado.',
                style: TextStyle(color: SigmaColors.muted),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                horizontalMargin: 14,
                columnSpacing: 22,
                headingRowHeight: 44,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 58,
                dividerThickness: .55,
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFF7F8FC),
                ),
                headingTextStyle: const TextStyle(
                  color: Color(0xFF475467),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
                columns: const [
                  DataColumn(label: Text('N°')),
                  DataColumn(label: Text('Fecha')),
                  DataColumn(label: Text('Estado')),
                  DataColumn(label: Text('Origen')),
                  DataColumn(label: Text('Registros')),
                  DataColumn(label: Text('Entrenamiento')),
                  DataColumn(label: Text('Prueba')),
                  DataColumn(label: Text('MAE')),
                  DataColumn(label: Text('RMSE')),
                  DataColumn(label: Text('R²')),
                  DataColumn(label: Text('Calidad')),
                ],
                rows: runs.take(20).toList().asMap().entries.map((entry) {
                  final index = entry.key;
                  final run = entry.value;
                  final metrics = _map(run['metrics']);
                  final status = (run['status'] ?? '').toString();

                  return DataRow(
                    color: WidgetStatePropertyAll(
                      index.isEven ? Colors.white : const Color(0xFFFBFCFE),
                    ),
                    cells: [
                      DataCell(
                        Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: SigmaColors.muted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      DataCell(Text(_dateTime(run['generated_at']))),
                      DataCell(
                        Text(
                          _statusLabel(status),
                          style: TextStyle(
                            color: _statusColor(status),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      DataCell(Text(_triggerLabel(run['trigger']))),
                      DataCell(Text(_asInt(run['source_rows']).toString())),
                      DataCell(Text(_asInt(run['training_rows']).toString())),
                      DataCell(Text(_asInt(run['test_rows']).toString())),
                      DataCell(Text(_metric(metrics['mae']))),
                      DataCell(Text(_metric(metrics['rmse']))),
                      DataCell(Text(_metric(metrics['r2']))),
                      DataCell(_QualityPill(r2: _parseDouble(metrics['r2']))),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _QualityPill extends StatelessWidget {
  const _QualityPill({required this.r2});

  final double? r2;

  @override
  Widget build(BuildContext context) {
    final quality = _qualityBand(r2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: quality.color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        quality.shortLabel,
        style: TextStyle(
          color: quality.color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _QualityBand {
  const _QualityBand({
    required this.label,
    required this.shortLabel,
    required this.description,
    required this.color,
    required this.icon,
  });

  final String label;
  final String shortLabel;
  final String description;
  final Color color;
  final IconData icon;
}

_QualityBand _qualityBand(double? r2) {
  if (r2 == null) {
    return const _QualityBand(
      label: 'Sin evaluación estadística',
      shortLabel: 'Sin evaluar',
      description: 'No existe un valor R² disponible para esta ejecución.',
      color: SigmaColors.muted,
      icon: Icons.analytics_outlined,
    );
  }

  if (r2 >= .80) {
    return const _QualityBand(
      label: 'Calidad alta',
      shortLabel: 'Alta',
      description:
          'El modelo muestra una capacidad explicativa alta sobre el conjunto de prueba y puede aportar una referencia sólida para la planificación.',
      color: SigmaColors.success,
      icon: Icons.verified_rounded,
    );
  }

  if (r2 >= .60) {
    return const _QualityBand(
      label: 'Calidad buena',
      shortLabel: 'Buena',
      description:
          'El modelo explica una proporción importante de la variación observada. Sus resultados son útiles como apoyo, manteniendo seguimiento periódico de las métricas.',
      color: Color(0xFF0F766E),
      icon: Icons.thumb_up_alt_outlined,
    );
  }

  if (r2 >= .40) {
    return const _QualityBand(
      label: 'Calidad moderada',
      shortLabel: 'Moderada',
      description:
          'El modelo identifica una parte relevante del patrón histórico, aunque todavía existe variabilidad no explicada. Conviene usar la predicción como apoyo y no como único criterio.',
      color: SigmaColors.warning,
      icon: Icons.insights_rounded,
    );
  }

  if (r2 >= 0) {
    return const _QualityBand(
      label: 'Calidad referencial',
      shortLabel: 'Referencial',
      description:
          'El modelo tiene capacidad explicativa limitada. La predicción puede utilizarse como referencia exploratoria mientras se acumula y valida más historial.',
      color: Color(0xFFD97706),
      icon: Icons.science_outlined,
    );
  }

  return const _QualityBand(
    label: 'Calidad insuficiente',
    shortLabel: 'Insuficiente',
    description:
        'El R² es negativo: en esta validación el modelo no supera una referencia simple. No conviene basar decisiones en esta predicción hasta revisar datos o variables.',
    color: SigmaColors.danger,
    icon: Icons.error_outline_rounded,
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.status, required this.message});
  final String status;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return SigmaCard(
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: SigmaColors.muted,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const SigmaCard(
      child: SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
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
          const Icon(Icons.error_outline_rounded, color: SigmaColors.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: SigmaColors.danger),
            ),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class _PredictionPageData {
  const _PredictionPageData({
    required this.status,
    required this.latest,
    required this.runs,
    required this.series,
  });

  final Map<String, dynamic> status;
  final Map<String, dynamic> latest;
  final List<Map<String, dynamic>> runs;
  final Map<String, dynamic> series;

  factory _PredictionPageData.empty() =>
      const _PredictionPageData(status: {}, latest: {}, runs: [], series: {});
}

class _PredictionModelOption {
  const _PredictionModelOption({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
    required this.isCurrency,
  });

  final String value;
  final String label;
  final String description;
  final IconData icon;
  final bool isCurrency;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _listOfMaps(dynamic value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

Map<String, dynamic>? _firstMapWhere(
  List<Map<String, dynamic>> items,
  bool Function(Map<String, dynamic> item) test,
) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  final normalized = value?.toString().trim().replaceAll(',', '.') ?? '';
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

String _metric(dynamic value) {
  final number = _parseDouble(value);
  return number == null ? '—' : number.toStringAsFixed(4);
}

String _money(dynamic value) {
  final number = _parseDouble(value);
  if (number == null) return '—';
  return 'Bs ${NumberFormat('#,##0.00', 'es').format(number)}';
}

String _predictionValue(dynamic value, _PredictionModelOption model) {
  final number = _parseDouble(value);
  if (number == null) return '—';

  if (model.isCurrency) {
    return _money(number);
  }

  return '${NumberFormat('#,##0.0', 'es').format(number)} pedidos';
}

String _metricWithUnit(dynamic value, _PredictionModelOption model) {
  final number = _parseDouble(value);
  if (number == null) return '—';

  if (model.isCurrency) {
    return _money(number);
  }

  return '${NumberFormat('#,##0.00', 'es').format(number)} pedidos';
}

String _csvNumber(dynamic value) {
  final number = _parseDouble(value);
  return number == null ? '' : number.toStringAsFixed(2).replaceAll('.', ',');
}

String _escapeCsv(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

String _date(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed == null
      ? (value ?? '—').toString()
      : DateFormat('dd/MM/yyyy').format(parsed);
}

String _shortDate(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed == null
      ? (value ?? '—').toString()
      : DateFormat('dd/MM').format(parsed);
}

String _dateTime(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed == null
      ? (value ?? '—').toString()
      : DateFormat('dd/MM/yyyy HH:mm').format(parsed.toLocal());
}

String _statusLabel(String status) {
  return switch (status.toLowerCase()) {
    'ok' => 'Entrenado',
    'insufficient_data' => 'Datos insuficientes',
    'error' || 'failed' => 'Error',
    _ => 'Sin ejecución',
  };
}

Color _statusColor(String status) {
  return switch (status.toLowerCase()) {
    'ok' => SigmaColors.success,
    'insufficient_data' => SigmaColors.warning,
    'error' || 'failed' => SigmaColors.danger,
    _ => SigmaColors.muted,
  };
}

String _triggerLabel(dynamic value) {
  return switch ((value ?? '').toString().toLowerCase()) {
    'manual' => 'Manual',
    'scheduler' => 'Automático',
    _ => '—',
  };
}

String _scheduleFor(Map<String, dynamic> status, String modelType) {
  final scheduler = _map(status['scheduler']);
  return (scheduler[modelType] ?? 'Programación no disponible').toString();
}

String _cleanError(Object? error) {
  return (error ?? 'Error desconocido')
      .toString()
      .replaceFirst('Exception: ', '')
      .trim();
}
