import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/providers/supervisor_provider.dart';
import '../../../utils/app_theme.dart';
import 'supervisor_mobile_ui.dart';

class SupervisorMobileRoutesView extends StatefulWidget {
  const SupervisorMobileRoutesView({super.key});

  @override
  State<SupervisorMobileRoutesView> createState() =>
      _SupervisorMobileRoutesViewState();
}

class _SupervisorMobileRoutesViewState
    extends State<SupervisorMobileRoutesView> {
  final SupervisorProvider _provider = Get.find<SupervisorProvider>();

  DateTime _date = DateTime.now();
  List<Map<String, dynamic>> _routes = [];
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
      final rows = await _provider.rutasHoy(_date);
      if (!mounted) return;
      setState(() => _routes = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime get _lastAllowedDate =>
      DateTime.now().add(const Duration(days: 365));

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 3),
      lastDate: _lastAllowedDate,
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
    await _load();
  }

  Future<void> _moveDate(int days) async {
    final next = _date.add(Duration(days: days));
    if (next.isAfter(_lastAllowedDate)) return;
    setState(() => _date = next);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final totalPoints = _routes.fold<int>(
      0,
      (sum, route) =>
          sum +
          ((route['detalles'] is List)
              ? (route['detalles'] as List).length
              : 0),
    );

    final zones = _routes
        .map((row) => _mapOf(row['zona'])['zona_nombre']?.toString().trim())
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .toSet()
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Rutas del equipo')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
          children: [
            const SupervisorPageHero(
              icon: Icons.alt_route_rounded,
              title: 'Planificación del equipo',
              subtitle:
                  'Consulta qué visitador tiene cada ruta, su zona y el orden de los puntos asignados.',
              badge: 'RUTAS',
            ),
            const SizedBox(height: 12),
            SupervisorDateNavigator(
              date: _date,
              onPrevious: () => _moveDate(-1),
              onNext: _date.isBefore(_lastAllowedDate)
                  ? () => _moveDate(1)
                  : null,
              onPick: _pickDate,
              label: 'Fecha de planificación',
              compact: true,
            ),
            const SizedBox(height: 12),
            SigmaCard(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 8) / 2;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: width,
                        child: SupervisorStatTile(
                          icon: Icons.route_rounded,
                          label: 'Rutas',
                          value: '${_routes.length}',
                          color: SigmaColors.primary,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: SupervisorStatTile(
                          icon: Icons.place_outlined,
                          label: 'Puntos',
                          value: '$totalPoints',
                          color: SigmaColors.secondary,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: SupervisorStatTile(
                          icon: Icons.groups_2_outlined,
                          label: 'Visitadores',
                          value: '${_routes.length}',
                          color: SigmaColors.success,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: SupervisorStatTile(
                          icon: Icons.map_outlined,
                          label: 'Zonas',
                          value: '$zones',
                          color: SigmaColors.warning,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              SupervisorErrorCard(message: _error!, onRetry: _load)
            else if (_loading)
              const SigmaCard(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_routes.isEmpty)
              const SupervisorEmptyState(
                icon: Icons.route_outlined,
                title: 'No hay rutas para esta fecha',
                message:
                    'Usa las flechas o el calendario para revisar otra planificación.',
              )
            else ...[
              const SupervisorSectionHeader(
                title: 'Rutas asignadas',
                subtitle: 'Toca una ruta para desplegar sus puntos de visita.',
              ),
              const SizedBox(height: 8),
              ..._routes.map((route) => _routeCard(context, route)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _routeCard(BuildContext context, Map<String, dynamic> route) {
    final visitor = _mapOf(route['visitador']);
    final zone = _mapOf(route['zona']);
    final details = route['detalles'] is List
        ? route['detalles'] as List
        : <dynamic>[];
    final visitorName =
        (visitor['usu_nombre'] ?? visitor['name'] ?? 'Visitador').toString();
    final zoneName = (zone['zona_nombre'] ?? route['zona_nombre'] ?? 'Sin zona')
        .toString();
    final routeName = (route['ruta_nombre'] ?? 'Ruta del día').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: SigmaCard(
        padding: EdgeInsets.zero,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(13, 5, 10, 5),
          childrenPadding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: SigmaColors.primary.withOpacity(.10),
            foregroundColor: SigmaColors.primary,
            child: Text(
              visitorName.isEmpty
                  ? 'V'
                  : visitorName.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          title: Text(
            visitorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$zoneName · ${details.length} punto(s)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  routeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 1),
            if (details.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Sin puntos de visita cargados.'),
                ),
              )
            else
              ...details.asMap().entries.map((entry) {
                final detail = _mapOf(entry.value);
                final client = _mapOf(detail['cliente']);
                final order = _intOf(detail['orden_visita']) ?? entry.key + 1;
                final address = (client['cliente_dir'] ?? '').toString().trim();
                final time = (detail['hora_planificada'] ?? '')
                    .toString()
                    .trim();

                return Container(
                  margin: const EdgeInsets.only(top: 9),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(.22),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: SigmaColors.secondary.withOpacity(.11),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$order',
                          style: const TextStyle(
                            color: SigmaColors.secondary,
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
                              (client['cliente_nombre'] ?? 'Punto de visita')
                                  .toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (time.isNotEmpty)
                              Text(
                                'Planificada: $time',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            if (address.isNotEmpty)
                              Text(
                                address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
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

String _cleanError(Object error) =>
    error.toString().replaceFirst('Exception: ', '').trim();
