import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../data/providers/web_api_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/file_exporter.dart';
import '../layout/web_panel_shell.dart';
import 'web_report_pdf_service.dart';
import 'web_widgets.dart';

class WebReportesView extends StatefulWidget {
  const WebReportesView({
    super.key,
    this.activeRoute = Routes.webAdminReportes,
    this.title = 'Reportes de ventas',
    this.subtitle =
        'Consulta visitas, pedidos, ventas y efectividad de visitas de forma sencilla.',
  });

  final String activeRoute;
  final String title;
  final String subtitle;

  @override
  State<WebReportesView> createState() => _WebReportesViewState();
}

class _WebReportesViewState extends State<WebReportesView> {
  final DateFormat _apiDate = DateFormat('yyyy-MM-dd');
  final DateFormat _displayDate = DateFormat('dd/MM/yyyy');

  late DateTime _desde;
  late DateTime _hasta;
  int _reloadVersion = 0;
  int _reportView = 0;

  bool _exportingPdf = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _desde = DateTime(now.year, now.month, 1);
    _hasta = now;
  }

  Map<String, dynamic> get _query => {
    'desde': _apiDate.format(_desde),
    'hasta': _apiDate.format(_hasta),
  };

  Future<void> _pickDesde() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _desde,
      firstDate: DateTime(2020),
      lastDate: _hasta,
    );
    if (selected == null) return;
    setState(() => _desde = selected);
  }

  Future<void> _pickHasta() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _hasta,
      firstDate: _desde,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null) return;
    setState(() => _hasta = selected);
  }

  void _applyFilters() {
    setState(() => _reloadVersion++);
  }

  void _currentMonth() {
    final now = DateTime.now();
    setState(() {
      _desde = DateTime(now.year, now.month, 1);
      _hasta = now;
      _reloadVersion++;
    });
  }

  void _lastSevenDays() {
    final now = DateTime.now();
    setState(() {
      _desde = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6));
      _hasta = now;
      _reloadVersion++;
    });
  }

  Future<void> _generatePdf({required bool preview}) async {
    if (_exportingPdf) return;
    setState(() => _exportingPdf = true);

    try {
      final provider = Get.find<WebApiProvider>();
      final bytes = await WebReportPdfService.build(
        provider: provider,
        desde: _desde,
        hasta: _hasta,
        title: widget.title,
      );
      final fileName =
          'SIGPRED_reporte_${_apiDate.format(_desde)}_${_apiDate.format(_hasta)}.pdf';

      if (preview) {
        FileExporter.previewBytes(bytes: bytes, mimeType: 'application/pdf');
      } else {
        FileExporter.downloadBytes(
          fileName: fileName,
          bytes: bytes,
          mimeType: 'application/pdf',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            preview
                ? 'Vista previa PDF generada.'
                : 'Reporte PDF generado: $fileName',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo generar el PDF: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebPanelShell(
      title: widget.title,
      subtitle: widget.subtitle,
      activeRoute: widget.activeRoute,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReportFilterCard(
            desde: _displayDate.format(_desde),
            hasta: _displayDate.format(_hasta),
            onPickDesde: _pickDesde,
            onPickHasta: _pickHasta,
            onApply: _applyFilters,
            onCurrentMonth: _currentMonth,
            onLastSevenDays: _lastSevenDays,
          ),
          const SizedBox(height: 16),
          _ReportSummary(
            key: ValueKey('summary-$_reloadVersion'),
            query: _query,
          ),
          const SizedBox(height: 16),
          _ReportViewToolbar(
            selected: _reportView,
            exporting: _exportingPdf,
            onSelected: (value) => setState(() => _reportView = value),
            onPreview: () => _generatePdf(preview: true),
            onDownload: () => _generatePdf(preview: false),
          ),
          const SizedBox(height: 16),
          _selectedReportTable(),
        ],
      ),
    );
  }

  Widget _selectedReportTable() {
    switch (_reportView) {
      case 1:
        return WebDataTableCard(
          key: ValueKey('visitador-$_reloadVersion'),
          title: 'Rendimiento por visitador médico',
          subtitle:
              'Compara visitas realizadas, visitas con pedido y ventas generadas por cada visitador.',
          endpoint: '/reportes/rendimiento-visitador',
          query: _query,
          emptyMessage: 'No hay datos para los filtros seleccionados.',
          columns: const [
            WebTableColumn(
              label: 'Visitador',
              value: _visitadorValue,
              width: 260,
            ),
            WebTableColumn(
              label: 'Visitas realizadas',
              value: _visitsValue,
              width: 100,
            ),
            WebTableColumn(
              label: 'Efectivas (con pedido)',
              value: _effectiveValue,
              width: 100,
            ),
            WebTableColumn(
              label: 'Efectividad de visitas',
              value: _percentValue,
              width: 120,
            ),
            WebTableColumn(
              label: 'Pedidos generados',
              value: _ordersValue,
              width: 100,
            ),
            WebTableColumn(
              label: 'Ventas (Bs)',
              value: _amountValue,
              width: 150,
            ),
          ],
        );
      case 2:
        return WebDataTableCard(
          key: ValueKey('cliente-$_reloadVersion'),
          title: 'Resultados por punto de visita',
          subtitle:
              'Identifica qué clientes concentran visitas efectivas, pedidos y ventas durante el periodo.',
          endpoint: '/reportes/efectividad-cliente',
          query: _query,
          emptyMessage: 'No hay datos para los filtros seleccionados.',
          columns: const [
            WebTableColumn(
              label: 'Punto de visita',
              value: _clientValue,
              width: 280,
            ),
            WebTableColumn(label: 'Zona', value: _zoneValue, width: 200),
            WebTableColumn(
              label: 'Visitas realizadas',
              value: _visitsValue,
              width: 100,
            ),
            WebTableColumn(
              label: 'Efectivas (con pedido)',
              value: _effectiveValue,
              width: 100,
            ),
            WebTableColumn(
              label: 'Efectividad de visitas',
              value: _percentValue,
              width: 120,
            ),
            WebTableColumn(
              label: 'Pedidos generados',
              value: _ordersValue,
              width: 100,
            ),
            WebTableColumn(
              label: 'Ventas (Bs)',
              value: _amountValue,
              width: 150,
            ),
          ],
        );
      default:
        return WebDataTableCard(
          key: ValueKey('zona-$_reloadVersion'),
          title: 'Resultados por zona',
          subtitle:
              'Compara visitas, pedidos, ventas y efectividad de visitas entre zonas.',
          endpoint: '/reportes/efectividad-zona',
          query: _query,
          emptyMessage: 'No hay datos para los filtros seleccionados.',
          columns: const [
            WebTableColumn(label: 'Zona', value: _zoneValue, width: 240),
            WebTableColumn(
              label: 'Visitas realizadas',
              value: _visitsValue,
              width: 100,
            ),
            WebTableColumn(
              label: 'Efectivas (con pedido)',
              value: _effectiveValue,
              width: 100,
            ),
            WebTableColumn(
              label: 'Efectividad de visitas',
              value: _percentValue,
              width: 120,
            ),
            WebTableColumn(
              label: 'Pedidos generados',
              value: _ordersValue,
              width: 100,
            ),
            WebTableColumn(
              label: 'Ventas (Bs)',
              value: _amountValue,
              width: 150,
            ),
          ],
        );
    }
  }
}

class _ReportSummary extends StatefulWidget {
  const _ReportSummary({super.key, required this.query});

  final Map<String, dynamic> query;

  @override
  State<_ReportSummary> createState() => _ReportSummaryState();
}

class _ReportSummaryState extends State<_ReportSummary> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<dynamic>> _load() {
    return Get.find<WebApiProvider>().getList(
      '/reportes/efectividad-zona',
      widget.query,
    );
  }

  void _retry() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SigmaCard(
            child: SizedBox(
              height: 108,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            ),
          );
        }

        if (snapshot.hasError) {
          return SigmaCard(
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: SigmaColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No fue posible calcular el resumen del periodo.',
                    style: const TextStyle(
                      color: SigmaColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Reintentar'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                ),
              ],
            ),
          );
        }

        final items = (snapshot.data ?? const <dynamic>[])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        final visits = _sumReport(items, ['visitas', 'total_visitas', 'total']);
        final effective = _sumReport(items, [
          'efectivas',
          'visitas_efectivas',
          'efectiva',
        ]);
        final orders = _sumReport(items, ['pedidos', 'total_pedidos']);
        final amount = _sumReport(items, [
          'monto_total',
          'monto',
          'total_monto',
        ]);
        final effectiveness = visits <= 0 ? 0.0 : effective * 100 / visits;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumen del periodo',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: SigmaColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Lectura rápida de las visitas que generaron pedidos y del resultado de ventas del periodo.',
              style: TextStyle(
                color: SigmaColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            WebMetricGrid(
              metrics: [
                WebMetric(
                  label: 'Visitas realizadas',
                  value: visits.round().toString(),
                  icon: Icons.event_available_outlined,
                  color: SigmaColors.secondary,
                ),
                WebMetric(
                  label: 'Efectivas (con pedido)',
                  value: effective.round().toString(),
                  icon: Icons.check_circle_outline_rounded,
                  color: SigmaColors.success,
                ),
                WebMetric(
                  label: 'Pedidos generados',
                  value: orders.round().toString(),
                  icon: Icons.shopping_cart_outlined,
                  color: SigmaColors.primary,
                ),
                WebMetric(
                  label: 'Efectividad de visitas',
                  value: '${effectiveness.toStringAsFixed(1)}%',
                  icon: Icons.analytics_outlined,
                  color: SigmaColors.warning,
                ),
                WebMetric(
                  label: 'Ventas (monto de pedidos)',
                  value: 'Bs ${NumberFormat('#,##0.00', 'es').format(amount)}',
                  icon: Icons.payments_outlined,
                  color: SigmaColors.primary,
                ),
              ],
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
                    Icons.info_outline_rounded,
                    size: 19,
                    color: SigmaColors.success,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Una visita efectiva es una visita que generó un pedido. La efectividad de visitas representa qué porcentaje de las visitas realizadas terminó en pedido.',
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
        );
      },
    );
  }
}

class _ReportViewToolbar extends StatelessWidget {
  const _ReportViewToolbar({
    required this.selected,
    required this.exporting,
    required this.onSelected,
    required this.onPreview,
    required this.onDownload,
  });

  final int selected;
  final bool exporting;
  final ValueChanged<int> onSelected;
  final VoidCallback onPreview;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return SigmaCard(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 880;
          final selector = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Detalle del reporte',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: SigmaColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Elige una vista. Se muestra una tabla a la vez para evitar información repetida.',
                style: TextStyle(
                  color: SigmaColors.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.map_outlined),
                    label: Text('Zonas'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.badge_outlined),
                    label: Text('Visitadores'),
                  ),
                  ButtonSegment(
                    value: 2,
                    icon: Icon(Icons.storefront_outlined),
                    label: Text('Clientes'),
                  ),
                ],
                selected: {selected},
                onSelectionChanged: (values) => onSelected(values.first),
              ),
            ],
          );

          final export = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: exporting ? null : onPreview,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Vista previa PDF'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              ),
              FilledButton.icon(
                onPressed: exporting ? null : onDownload,
                icon: exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: Text(exporting ? 'Generando...' : 'Descargar PDF'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: SigmaColors.primary,
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [selector, const SizedBox(height: 14), export],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: selector),
              const SizedBox(width: 18),
              export,
            ],
          );
        },
      ),
    );
  }
}

double _sumReport(List<Map<String, dynamic>> items, List<String> keys) {
  var total = 0.0;
  for (final item in items) {
    final raw = valueOf(item, keys, '0').replaceAll(',', '.');
    total += double.tryParse(raw) ?? 0;
  }
  return total;
}

class _ReportFilterCard extends StatelessWidget {
  const _ReportFilterCard({
    required this.desde,
    required this.hasta,
    required this.onPickDesde,
    required this.onPickHasta,
    required this.onApply,
    required this.onCurrentMonth,
    required this.onLastSevenDays,
  });

  final String desde;
  final String hasta;
  final VoidCallback onPickDesde;
  final VoidCallback onPickHasta;
  final VoidCallback onApply;
  final VoidCallback onCurrentMonth;
  final VoidCallback onLastSevenDays;

  @override
  Widget build(BuildContext context) {
    return SigmaCard(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 900;

          final controls = Wrap(
            spacing: 9,
            runSpacing: 9,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _CompactDateButton(
                label: 'Desde',
                value: desde,
                icon: Icons.calendar_today_outlined,
                onPressed: onPickDesde,
              ),
              _CompactDateButton(
                label: 'Hasta',
                value: hasta,
                icon: Icons.event_available_outlined,
                onPressed: onPickHasta,
              ),
              _QuickPeriodButton(
                label: 'Últimos 7 días',
                icon: Icons.date_range_outlined,
                onPressed: onLastSevenDays,
              ),
              _QuickPeriodButton(
                label: 'Mes actual',
                icon: Icons.today_outlined,
                onPressed: onCurrentMonth,
              ),
              SizedBox(
                height: 44,
                child: FilledButton.icon(
                  onPressed: onApply,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Aplicar'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor: SigmaColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ReportFilterIntro(),
                const SizedBox(height: 13),
                controls,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 235, child: _ReportFilterIntro()),
              const SizedBox(width: 20),
              Expanded(child: controls),
            ],
          );
        },
      ),
    );
  }
}

class _ReportFilterIntro extends StatelessWidget {
  const _ReportFilterIntro();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Periodo del reporte',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: SigmaColors.ink,
          ),
        ),
        SizedBox(height: 3),
        Text(
          'Elige fechas o usa un periodo rápido.',
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

class _CompactDateButton extends StatelessWidget {
  const _CompactDateButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 178,
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          foregroundColor: SigmaColors.ink,
          side: const BorderSide(color: Color(0xFFD9DEE8)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: SigmaColors.primary),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: SigmaColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SigmaColors.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickPeriodButton extends StatelessWidget {
  const _QuickPeriodButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label),
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          foregroundColor: const Color(0xFF475467),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

String _zoneValue(Map<String, dynamic> item) =>
    valueOf(item, ['zona_nombre', 'zona', 'name', 'nombre']);
String _visitadorValue(Map<String, dynamic> item) =>
    valueOf(item, ['usu_nombre', 'visitador_nombre', 'nombre']);
String _clientValue(Map<String, dynamic> item) =>
    valueOf(item, ['cliente_nombre', 'cliente', 'nombre']);
String _visitsValue(Map<String, dynamic> item) =>
    valueOf(item, ['visitas', 'total_visitas', 'total']);
String _effectiveValue(Map<String, dynamic> item) =>
    valueOf(item, ['efectivas', 'visitas_efectivas', 'efectiva']);
String _ordersValue(Map<String, dynamic> item) =>
    valueOf(item, ['pedidos', 'total_pedidos']);
String _percentValue(Map<String, dynamic> item) {
  final value = valueOf(item, [
    'efectividad_porcentaje',
    'porcentaje',
    'efectividad',
    'rate',
  ], '0');
  return '$value%';
}

String _amountValue(Map<String, dynamic> item) {
  final raw = valueOf(item, ['monto_total', 'monto', 'total_monto'], '0');
  final number = double.tryParse(raw.replaceAll(',', '.')) ?? 0;
  return 'Bs ${NumberFormat('#,##0.00', 'es').format(number)}';
}
