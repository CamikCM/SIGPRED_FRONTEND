import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../data/providers/web_api_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../utils/app_theme.dart';
import '../layout/web_panel_shell.dart';
import 'web_widgets.dart';

class WebVisitasView extends StatefulWidget {
  const WebVisitasView({
    super.key,
    this.activeRoute = Routes.webSupervisorVisitas,
    this.title = 'Visitas y resultados',
    this.subtitle =
        'Consulta quién realizó cada visita, a qué cliente, cuándo se registró y cuál fue su resultado.',
  });

  final String activeRoute;
  final String title;
  final String subtitle;

  @override
  State<WebVisitasView> createState() => _WebVisitasViewState();
}

class _WebVisitasViewState extends State<WebVisitasView> {
  static const int _perPage = 25;

  final TextEditingController _searchController = TextEditingController();

  late Future<_VisitsPageData> _future;
  late Future<_VisitCatalogs> _catalogsFuture;

  DateTime? _from;
  DateTime? _to;
  int _visitadorId = 0;
  String _effective = 'all';
  int _page = 1;

  final DateFormat _apiDate = DateFormat('yyyy-MM-dd');
  final DateFormat _displayDate = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month, now.day);

    _catalogsFuture = _loadCatalogs();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _baseQuery() {
    return {
      'per_page': _perPage,
      'page': _page,
      if (_from != null) 'desde': _apiDate.format(_from!),
      if (_to != null) 'hasta': _apiDate.format(_to!),
      if (_visitadorId > 0) 'visitador_id': _visitadorId,
      if (_searchController.text.trim().isNotEmpty)
        'search': _searchController.text.trim(),
    };
  }

  Map<String, dynamic> _summaryQuery() {
    return {
      'per_page': 1,
      if (_from != null) 'desde': _apiDate.format(_from!),
      if (_to != null) 'hasta': _apiDate.format(_to!),
      if (_visitadorId > 0) 'visitador_id': _visitadorId,
      if (_searchController.text.trim().isNotEmpty)
        'search': _searchController.text.trim(),
    };
  }

  Future<_VisitsPageData> _load() async {
    final provider = Get.find<WebApiProvider>();

    final pageQuery = _baseQuery();
    if (_effective != 'all') {
      pageQuery['efectiva'] = _effective == 'effective';
    }

    final summary = _summaryQuery();

    final responses = await Future.wait<Map<String, dynamic>>([
      provider.getMap('/visitas', pageQuery),
      provider.getMap('/visitas', summary),
      provider.getMap('/visitas', {...summary, 'efectiva': true}),
      provider.getMap('/visitas', {...summary, 'efectiva': false}),
      provider.getMap('/visitas', {...summary, 'con_pedido': true}),
    ]);

    final pageResponse = responses[0];

    return _VisitsPageData(
      items: _listOfMaps(pageResponse['data']),
      total: _asInt(pageResponse['total']),
      currentPage: _asInt(pageResponse['current_page'], fallback: _page),
      lastPage: _asInt(pageResponse['last_page'], fallback: 1),
      totalContext: _asInt(responses[1]['total']),
      effectiveCount: _asInt(responses[2]['total']),
      ineffectiveCount: _asInt(responses[3]['total']),
      withOrderCount: _asInt(responses[4]['total']),
    );
  }

  Future<_VisitCatalogs> _loadCatalogs() async {
    final provider = Get.find<WebApiProvider>();

    final responses = await Future.wait<List<dynamic>>([
      provider.getList('/usuarios', {'rol_id': 3, 'per_page': 100}),
    ]);

    final users = _listOfMaps(responses[0]);

    return _VisitCatalogs(visitadores: users);
  }

  void _reload({bool firstPage = true}) {
    if (!mounted) return;

    setState(() {
      if (firstPage) _page = 1;
      _future = _load();
    });
  }

  Future<void> _pickFrom() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (value == null || !mounted) return;

    setState(() {
      _from = value;
      if (_to != null && _to!.isBefore(value)) {
        _to = value;
      }
    });
  }

  Future<void> _pickTo() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: _from ?? DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (value == null || !mounted) return;

    setState(() => _to = value);
  }

  void _setCurrentMonth() {
    final now = DateTime.now();
    setState(() {
      _from = DateTime(now.year, now.month, 1);
      _to = DateTime(now.year, now.month, now.day);
      _page = 1;
      _future = _load();
    });
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _from = null;
      _to = null;
      _visitadorId = 0;
      _effective = 'all';
      _page = 1;
      _future = _load();
    });
  }

  void _goToPage(int page) {
    if (page < 1) return;

    setState(() {
      _page = page;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return WebPanelShell(
      title: widget.title,
      subtitle: widget.subtitle,
      activeRoute: widget.activeRoute,
      badge: 'OPERACIÓN',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<_VisitCatalogs>(
            future: _catalogsFuture,
            builder: (context, snapshot) {
              return _VisitFilters(
                searchController: _searchController,
                visitadores:
                    snapshot.data?.visitadores ??
                    const <Map<String, dynamic>>[],
                visitadorId: _visitadorId,
                effective: _effective,
                fromLabel: _from == null
                    ? 'Sin límite'
                    : _displayDate.format(_from!),
                toLabel: _to == null ? 'Sin límite' : _displayDate.format(_to!),
                onVisitadorChanged: (value) {
                  setState(() => _visitadorId = value ?? 0);
                },
                onEffectiveChanged: (value) {
                  setState(() => _effective = value ?? 'all');
                },
                onPickFrom: _pickFrom,
                onPickTo: _pickTo,
                onCurrentMonth: _setCurrentMonth,
                onApply: () => _reload(),
                onClear: _clearFilters,
              );
            },
          ),
          const SizedBox(height: 16),
          FutureBuilder<_VisitsPageData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _LoadingVisits();
              }

              if (snapshot.hasError) {
                return _VisitsError(
                  message: snapshot.error.toString(),
                  onRetry: () => _reload(firstPage: false),
                );
              }

              final data = snapshot.data ?? _VisitsPageData.empty();
              final effectiveness = data.totalContext <= 0
                  ? 0.0
                  : (data.effectiveCount / data.totalContext) * 100;

              final visibleItems = _applyLocalSearch(data.items);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WebMetricGrid(
                    metrics: [
                      WebMetric(
                        label: 'Total de visitas',
                        value: data.totalContext.toString(),
                        icon: Icons.fact_check_outlined,
                        color: SigmaColors.primary,
                      ),
                      WebMetric(
                        label: 'Visitas efectivas',
                        value: data.effectiveCount.toString(),
                        icon: Icons.check_circle_outline_rounded,
                        color: SigmaColors.success,
                      ),
                      WebMetric(
                        label: 'No efectivas',
                        value: data.ineffectiveCount.toString(),
                        icon: Icons.cancel_outlined,
                        color: SigmaColors.warning,
                      ),
                      WebMetric(
                        label: 'Con pedido',
                        value: data.withOrderCount.toString(),
                        icon: Icons.shopping_bag_outlined,
                        color: SigmaColors.secondary,
                      ),
                      WebMetric(
                        label: 'Efectividad',
                        value: '${effectiveness.toStringAsFixed(1)}%',
                        icon: Icons.trending_up_rounded,
                        color: SigmaColors.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _VisitsTable(
                    items: visibleItems,
                    totalFiltered: data.total,
                    currentPage: data.currentPage,
                    lastPage: data.lastPage,
                    perPage: _perPage,
                    onPrevious: data.currentPage > 1
                        ? () => _goToPage(data.currentPage - 1)
                        : null,
                    onNext: data.currentPage < data.lastPage
                        ? () => _goToPage(data.currentPage + 1)
                        : null,
                    onOpen: _showVisitDetail,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _applyLocalSearch(
    List<Map<String, dynamic>> items,
  ) {
    // El servidor ya aplica la búsqueda. Esta segunda capa hace que los
    // resultados permanezcan consistentes cuando la respuesta incluye
    // estructuras anidadas con nombres.
    final term = _searchController.text.trim().toLowerCase();
    if (term.isEmpty) return items;

    return items.where((item) {
      final values = [
        _visitadorName(item),
        _clientName(item),
        _zoneName(item),
        _resultText(item),
        _idText(item),
      ];

      return values.any((value) => value.toLowerCase().contains(term));
    }).toList();
  }

  Future<void> _showVisitDetail(Map<String, dynamic> item) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _VisitDetailDialog(item: item),
    );
  }
}

class _VisitFilters extends StatelessWidget {
  const _VisitFilters({
    required this.searchController,
    required this.visitadores,
    required this.visitadorId,
    required this.effective,
    required this.fromLabel,
    required this.toLabel,
    required this.onVisitadorChanged,
    required this.onEffectiveChanged,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onCurrentMonth,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController searchController;
  final List<Map<String, dynamic>> visitadores;
  final int visitadorId;
  final String effective;
  final String fromLabel;
  final String toLabel;
  final ValueChanged<int?> onVisitadorChanged;
  final ValueChanged<String?> onEffectiveChanged;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onCurrentMonth;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SigmaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.filter_alt_outlined,
                size: 20,
                color: SigmaColors.primary,
              ),
              SizedBox(width: 8),
              Text(
                'Buscar y filtrar visitas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: SigmaColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Encuentra una visita por persona, cliente o resultado y limita el periodo que deseas revisar.',
            style: TextStyle(
              color: SigmaColors.muted,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: searchController,
                  onSubmitted: (_) => onApply(),
                  decoration: const InputDecoration(
                    labelText: 'Buscar',
                    hintText: 'Visitador, cliente o resultado',
                    prefixIcon: Icon(Icons.search_rounded),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<int>(
                  key: ValueKey('visitador-$visitadorId-${visitadores.length}'),
                  initialValue: visitadorId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Visitador',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: 0,
                      child: Text('Todos los visitadores'),
                    ),
                    ...visitadores.map(
                      (item) => DropdownMenuItem<int>(
                        value: _asInt(item['usu_id'] ?? item['id']),
                        child: Text(
                          valueOf(item, ['usu_nombre', 'nombre', 'name']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: onVisitadorChanged,
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('effective-$effective'),
                  initialValue: effective,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Resultado',
                    prefixIcon: Icon(Icons.task_alt_rounded),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Todas')),
                    DropdownMenuItem(
                      value: 'effective',
                      child: Text('Efectivas'),
                    ),
                    DropdownMenuItem(
                      value: 'ineffective',
                      child: Text('No efectivas'),
                    ),
                  ],
                  onChanged: onEffectiveChanged,
                ),
              ),
              _DateFilterButton(
                label: 'Desde',
                value: fromLabel,
                icon: Icons.calendar_today_outlined,
                onPressed: onPickFrom,
              ),
              _DateFilterButton(
                label: 'Hasta',
                value: toLabel,
                icon: Icons.event_available_outlined,
                onPressed: onPickTo,
              ),
              SizedBox(
                height: 44,
                child: TextButton.icon(
                  onPressed: onCurrentMonth,
                  icon: const Icon(Icons.today_outlined, size: 18),
                  label: const Text('Mes actual'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: const Color(0xFF475467),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: const Text('Limpiar'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: const Color(0xFF475467),
                    side: const BorderSide(color: Color(0xFFD9DEE8)),
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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

class _DateFilterButton extends StatelessWidget {
  const _DateFilterButton({
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
      width: 160,
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          foregroundColor: SigmaColors.ink,
          side: const BorderSide(color: Color(0xFFD9DEE8)),
          padding: const EdgeInsets.symmetric(horizontal: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: SigmaColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: SigmaColors.muted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SigmaColors.ink,
                      fontSize: 12,
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

class _VisitsTable extends StatelessWidget {
  const _VisitsTable({
    required this.items,
    required this.totalFiltered,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.onPrevious,
    required this.onNext,
    required this.onOpen,
  });

  final List<Map<String, dynamic>> items;
  final int totalFiltered;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) {
    final firstNumber = ((currentPage - 1) * perPage) + 1;
    final lastNumber = items.isEmpty ? 0 : firstNumber + items.length - 1;

    return SigmaCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registro de visitas',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: SigmaColors.ink,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Selecciona “Ver” para consultar el detalle completo de una visita.',
                        style: TextStyle(
                          color: SigmaColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: SigmaColors.primary.withOpacity(.08),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$totalFiltered registro${totalFiltered == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: SigmaColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEAECF0)),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 40,
                      color: SigmaColors.muted,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'No hay visitas para los filtros seleccionados.',
                      style: TextStyle(
                        color: SigmaColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                horizontalMargin: 14,
                columnSpacing: 22,
                headingRowHeight: 44,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 64,
                dividerThickness: .6,
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFF7F8FC),
                ),
                columns: const [
                  DataColumn(label: Text('N°')),
                  DataColumn(label: Text('ID visita')),
                  DataColumn(label: Text('Fecha y hora')),
                  DataColumn(label: Text('Visitador')),
                  DataColumn(label: Text('Cliente / zona')),
                  DataColumn(label: Text('Resultado')),
                  DataColumn(label: Text('Estado')),
                  DataColumn(label: Text('Pedido')),
                  DataColumn(label: Text('')),
                ],
                rows: List<DataRow>.generate(items.length, (index) {
                  final item = items[index];
                  final effective = _asBool(
                    _readPath(item, 'efectiva') ??
                        _readPath(item, 'vis_efectiva'),
                  );

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          (firstNumber + index).toString(),
                          style: const TextStyle(
                            color: SigmaColors.muted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          _idText(item),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      DataCell(
                        SizedBox(width: 128, child: Text(_visitDate(item))),
                      ),
                      DataCell(
                        SizedBox(
                          width: 175,
                          child: Text(
                            _visitadorName(item),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 215,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _clientName(item),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _zoneName(item),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: SigmaColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 190,
                          child: Text(
                            _resultText(item),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(_StatusBadge(effective: effective)),
                      DataCell(
                        SizedBox(
                          width: 110,
                          child: Text(
                            _orderText(item),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _hasOrder(item)
                                  ? SigmaColors.success
                                  : SigmaColors.muted,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Tooltip(
                          message: 'Ver detalle',
                          child: IconButton(
                            onPressed: () => onOpen(item),
                            icon: const Icon(
                              Icons.visibility_outlined,
                              color: SigmaColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          const Divider(height: 1, color: Color(0xFFEAECF0)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    items.isEmpty
                        ? 'Sin registros'
                        : 'Mostrando $firstNumber–$lastNumber de $totalFiltered',
                    style: const TextStyle(
                      color: SigmaColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Página anterior',
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(minWidth: 82),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4F7),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '$currentPage de $lastPage',
                    style: const TextStyle(
                      color: SigmaColors.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Página siguiente',
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.effective});

  final bool effective;

  @override
  Widget build(BuildContext context) {
    final color = effective ? SigmaColors.success : SigmaColors.warning;
    final label = effective ? 'Efectiva' : 'No efectiva';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _VisitDetailDialog extends StatelessWidget {
  const _VisitDetailDialog({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final effective = _asBool(
      _readPath(item, 'efectiva') ?? _readPath(item, 'vis_efectiva'),
    );
    final pedido = _asMap(item['pedido']);
    final details = _listOfMaps(pedido['detalles']);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 14, 16),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: SigmaColors.primary.withOpacity(.09),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.fact_check_outlined,
                      color: SigmaColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detalle de ${_idText(item)}',
                          style: const TextStyle(
                            color: SigmaColors.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _visitDate(item),
                          style: const TextStyle(
                            color: SigmaColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(effective: effective),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailSection(
                      title: 'Personas y ubicación',
                      icon: Icons.people_alt_outlined,
                      items: [
                        _DetailItem(
                          label: 'Visitador',
                          value: _visitadorName(item),
                        ),
                        _DetailItem(label: 'Cliente', value: _clientName(item)),
                        _DetailItem(label: 'Zona', value: _zoneName(item)),
                        _DetailItem(
                          label: 'Ruta',
                          value: valueOf(item, [
                            'jornada.ruta.ruta_nombre',
                            'ruta.ruta_nombre',
                          ]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailSection(
                      title: 'Resultado de la visita',
                      icon: Icons.assignment_turned_in_outlined,
                      items: [
                        _DetailItem(
                          label: 'Resultado',
                          value: _resultText(item),
                        ),
                        _DetailItem(
                          label: 'Tipo de atención',
                          value: valueOf(item, [
                            'tipo_atencion',
                            'vis_tipo_atencion',
                          ]),
                        ),
                        _DetailItem(
                          label: 'Motivo',
                          value: valueOf(item, ['motivo', 'vis_motivo']),
                        ),
                        _DetailItem(
                          label: 'Duración',
                          value: _durationText(item),
                        ),
                        _DetailItem(
                          label: 'Cumplimiento de ruta',
                          value: _complianceText(item),
                        ),
                        _DetailItem(
                          label: 'Distancia al punto',
                          value: _distanceText(item),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailSection(
                      title: 'Pedido asociado',
                      icon: Icons.shopping_bag_outlined,
                      items: [
                        _DetailItem(
                          label: 'Código',
                          value: valueOf(pedido, [
                            'pedido_codigo',
                            'codigo',
                          ], 'Sin pedido'),
                        ),
                        _DetailItem(label: 'Monto', value: _orderText(item)),
                        _DetailItem(
                          label: 'Entrega',
                          value: _simpleDate(pedido['fecha_entrega']),
                        ),
                        _DetailItem(
                          label: 'Productos',
                          value: details.isEmpty
                              ? 'Sin detalle'
                              : '${details.length} producto${details.length == 1 ? '' : 's'}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailSection(
                      title: 'Observaciones',
                      icon: Icons.notes_rounded,
                      items: [
                        _DetailItem(
                          label: 'Notas',
                          value: valueOf(item, [
                            'observaciones',
                            'vis_observaciones',
                          ], 'Sin observaciones'),
                          wide: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<_DetailItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEAECF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: SigmaColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: SigmaColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 20,
            runSpacing: 14,
            children: items.map((item) {
              return SizedBox(
                width: item.wide ? 720 : 225,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(
                        color: SigmaColors.muted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.value,
                      style: const TextStyle(
                        color: SigmaColors.ink,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DetailItem {
  const _DetailItem({
    required this.label,
    required this.value,
    this.wide = false,
  });

  final String label;
  final String value;
  final bool wide;
}

class _LoadingVisits extends StatelessWidget {
  const _LoadingVisits();

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

class _VisitsError extends StatelessWidget {
  const _VisitsError({required this.message, required this.onRetry});

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
              'No se pudieron cargar las visitas. $message',
              style: const TextStyle(
                color: SigmaColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class _VisitsPageData {
  const _VisitsPageData({
    required this.items,
    required this.total,
    required this.currentPage,
    required this.lastPage,
    required this.totalContext,
    required this.effectiveCount,
    required this.ineffectiveCount,
    required this.withOrderCount,
  });

  final List<Map<String, dynamic>> items;
  final int total;
  final int currentPage;
  final int lastPage;
  final int totalContext;
  final int effectiveCount;
  final int ineffectiveCount;
  final int withOrderCount;

  factory _VisitsPageData.empty() => const _VisitsPageData(
    items: [],
    total: 0,
    currentPage: 1,
    lastPage: 1,
    totalContext: 0,
    effectiveCount: 0,
    ineffectiveCount: 0,
    withOrderCount: 0,
  );
}

class _VisitCatalogs {
  const _VisitCatalogs({required this.visitadores});

  final List<Map<String, dynamic>> visitadores;
}

String _idText(Map<String, dynamic> item) {
  final id = _asInt(item['vis_id'] ?? item['visita_id'] ?? item['id']);
  return id <= 0 ? 'Sin ID' : 'VIS-${id.toString().padLeft(5, '0')}';
}

String _visitadorName(Map<String, dynamic> item) => valueOf(item, [
  'usuario.usu_nombre',
  'visitador.usu_nombre',
  'usuario_nombre',
], 'Sin visitador');

String _clientName(Map<String, dynamic> item) =>
    valueOf(item, ['cliente.cliente_nombre', 'cliente_nombre'], 'Sin cliente');

String _zoneName(Map<String, dynamic> item) => valueOf(item, [
  'cliente.zona.zona_nombre',
  'zona.zona_nombre',
  'zona_nombre',
], 'Sin zona');

String _resultText(Map<String, dynamic> item) => valueOf(item, [
  'resultado',
  'vis_resultado',
  'motivo',
], 'Sin resultado registrado');

String _visitDate(Map<String, dynamic> item) {
  final raw =
      _readPath(item, 'fecha_inicio') ??
      _readPath(item, 'vis_fecha_inicio') ??
      _readPath(item, 'created_at');

  if (raw == null) return 'Sin fecha';

  final parsed = DateTime.tryParse(raw.toString());
  if (parsed == null) return raw.toString();

  return DateFormat('dd/MM/yyyy HH:mm').format(parsed.toLocal());
}

String _simpleDate(dynamic raw) {
  if (raw == null || raw.toString().trim().isEmpty) return 'Sin fecha';

  final parsed = DateTime.tryParse(raw.toString());
  if (parsed == null) return raw.toString();

  return DateFormat('dd/MM/yyyy').format(parsed.toLocal());
}

bool _hasOrder(Map<String, dynamic> item) {
  final pedido = item['pedido'];
  return pedido is Map && pedido.isNotEmpty;
}

String _orderText(Map<String, dynamic> item) {
  final pedido = _asMap(item['pedido']);
  if (pedido.isEmpty) return 'Sin pedido';

  final amount = _asDouble(pedido['monto_total']);
  if (amount == null) return 'Con pedido';

  return 'Bs ${NumberFormat('#,##0.00').format(amount)}';
}

String _durationText(Map<String, dynamic> item) {
  final value = _asInt(
    _readPath(item, 'duracion_minutos') ??
        _readPath(item, 'vis_duracion_minutos'),
  );

  return value <= 0 ? 'No registrada' : '$value min';
}

String _complianceText(Map<String, dynamic> item) {
  final raw = _readPath(item, 'cumplimiento_ruta');
  if (raw == null) return 'No evaluado';
  return _asBool(raw) ? 'Cumplida' : 'Fuera del punto';
}

String _distanceText(Map<String, dynamic> item) {
  final value = _asDouble(_readPath(item, 'distancia_punto_m'));
  if (value == null) return 'No registrada';
  return '${value.toStringAsFixed(1)} m';
}

Map<String, dynamic> _asMap(dynamic value) {
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

Object? _readPath(Map<String, dynamic> item, String path) {
  dynamic current = item;

  for (final part in path.split('.')) {
    if (current is Map && current.containsKey(part)) {
      current = current[part];
    } else {
      return null;
    }
  }

  return current;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;

  final normalized = value?.toString().trim().toLowerCase();
  return normalized == 'true' ||
      normalized == '1' ||
      normalized == 'si' ||
      normalized == 'sí';
}
