import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/providers/web_api_provider.dart';
import '../../../utils/app_theme.dart';

class WebMetricGrid extends StatelessWidget {
  const WebMetricGrid({super.key, required this.metrics});
  final List<WebMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisExtent: 124,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return SigmaCard(
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: metric.color.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(metric.icon, color: metric.color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metric.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      metric.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SigmaColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class WebMetric {
  const WebMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.color = SigmaColors.primary,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class WebDataTableCard extends StatefulWidget {
  const WebDataTableCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.endpoint,
    required this.columns,
    this.query,
    this.emptyMessage = 'No se encontraron registros.',
    this.pageSize = 15,
  });

  final String title;
  final String? subtitle;
  final String endpoint;
  final List<WebTableColumn> columns;
  final Map<String, dynamic>? query;
  final String emptyMessage;
  final int pageSize;

  @override
  State<WebDataTableCard> createState() => _WebDataTableCardState();
}

class _WebDataTableCardState extends State<WebDataTableCard> {
  late Future<List<dynamic>> _future;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<dynamic>> _load() {
    return Get.find<WebApiProvider>().getList(widget.endpoint, widget.query);
  }

  void _retry() {
    setState(() {
      _page = 0;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SigmaCard(
      padding: const EdgeInsets.all(0),
      child: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final hasError = snapshot.hasError;
          final items = snapshot.data ?? <dynamic>[];
          final pageSize = widget.pageSize <= 0 ? 15 : widget.pageSize;
          final pageCount = items.isEmpty
              ? 1
              : ((items.length - 1) ~/ pageSize) + 1;
          final safePage = _page.clamp(0, pageCount - 1).toInt();
          final start = safePage * pageSize;
          final end = (start + pageSize).clamp(0, items.length).toInt();
          final visibleItems = items.sublist(start, end);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: SigmaColors.ink,
                            ),
                          ),
                          if (widget.subtitle != null &&
                              widget.subtitle!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle!,
                              style: const TextStyle(
                                color: SigmaColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFEAECF0)),
              if (hasError)
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: SigmaColors.danger,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No se pudo cargar la información.',
                          style: const TextStyle(
                            color: SigmaColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              else if (!isLoading && items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.inbox_outlined,
                          color: SigmaColors.muted,
                          size: 34,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.emptyMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: SigmaColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFFF8FAFC),
                    ),
                    columns: widget.columns
                        .map(
                          (column) => DataColumn(
                            label: Text(
                              column.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    rows: visibleItems.map((raw) {
                      final item = raw is Map
                          ? Map<String, dynamic>.from(raw)
                          : <String, dynamic>{'value': raw};
                      return DataRow(
                        cells: widget.columns.map((column) {
                          final value = column.value(item);
                          return DataCell(
                            SizedBox(
                              width: column.width,
                              child: Text(
                                value,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFEAECF0)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          items.isEmpty
                              ? 'Sin resultados'
                              : 'Mostrando ${start + 1}–$end de ${items.length} resultados',
                          style: const TextStyle(
                            color: SigmaColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton.outlined(
                        tooltip: 'Página anterior',
                        onPressed: safePage > 0
                            ? () => setState(() => _page = safePage - 1)
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'Página ${safePage + 1} de $pageCount',
                          style: const TextStyle(
                            color: SigmaColors.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton.outlined(
                        tooltip: 'Página siguiente',
                        onPressed: safePage < pageCount - 1
                            ? () => setState(() => _page = safePage + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class WebTableColumn {
  const WebTableColumn({
    required this.label,
    required this.value,
    this.width = 160,
  });
  final String label;
  final String Function(Map<String, dynamic> item) value;
  final double width;
}

String valueOf(
  Map<String, dynamic> item,
  List<String> keys, [
  String fallback = '-',
]) {
  for (final key in keys) {
    final value = _readPath(item, key);
    if (value != null && value.toString().trim().isNotEmpty)
      return value.toString();
  }
  return fallback;
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
