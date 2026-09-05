import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../data/providers/web_api_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../utils/app_theme.dart';
import '../layout/web_panel_shell.dart';
import 'web_management_widgets.dart';
import 'web_route_preview_map.dart';
import 'web_widgets.dart';

class WebRutasView extends StatefulWidget {
  const WebRutasView({
    super.key,
    this.activeRoute = Routes.webAdminRutas,
    this.title = 'Planificación de rutas',
    this.subtitle =
        'Planifica rutas y asigna puntos de visita al personal de campo.',
  });

  final String activeRoute;
  final String title;
  final String subtitle;

  @override
  State<WebRutasView> createState() => _WebRutasViewState();
}

class _WebRutasViewState extends State<WebRutasView> {
  final _provider = Get.find<WebApiProvider>();
  final _searchController = TextEditingController();
  final _dateFormat = DateFormat('yyyy-MM-dd');

  Map<String, dynamic> _catalog = {};
  List<Map<String, dynamic>> _routes = [];
  bool _loading = true;
  String? _error;
  DateTime _date = DateTime.now();
  int? _zoneFilter;
  int? _visitadorFilter;
  int? _stateFilter;

  bool get _canEdit => widget.activeRoute.startsWith('/web/admin');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _provider.getMap('/catalogos'),
        _provider.getMap('/rutas', {
          'per_page': 100,
          'fecha': _dateFormat.format(_date),
          if (_searchController.text.trim().isNotEmpty)
            'search': _searchController.text.trim(),
          if (_zoneFilter != null) 'zona_id': _zoneFilter,
          if (_visitadorFilter != null) 'visitador_id': _visitadorFilter,
          if (_stateFilter != null) 'est_id': _stateFilter,
        }),
      ]);
      if (!mounted) return;
      setState(() {
        _catalog = results[0];
        _routes = mapList(results[1]['data']);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _routes.where((r) => intValue(r['est_id']) == 1).length;
    final points = _routes.fold<int>(
      0,
      (total, route) =>
          total +
          (intValue(route['detalles_count']) ??
              mapList(route['detalles']).length),
    );
    final visitadores = _routes
        .map((r) => intValue(r['visitador_id']))
        .whereType<int>()
        .toSet()
        .length;

    return WebPanelShell(
      title: widget.title,
      subtitle: widget.subtitle,
      activeRoute: widget.activeRoute,
      child: Column(
        children: [
          WebFilterCard(
            title: 'Planificar y consultar',
            trailing: _canEdit
                ? WebPrimaryButton(
                    label: 'Nueva ruta',
                    icon: Icons.add_road_rounded,
                    onPressed: () => _openDialog(),
                  )
                : null,
            children: [
              WebFieldBox(
                width: 250,
                child: InkWell(
                  onTap: _pickFilterDate,
                  child: InputDecorator(
                    decoration: webInputDecoration('Fecha de planificación')
                        .copyWith(
                          suffixIcon: const Icon(Icons.calendar_month_rounded),
                        ),
                    child: Text(_dateFormat.format(_date)),
                  ),
                ),
              ),
              WebFieldBox(
                width: 310,
                child: TextField(
                  controller: _searchController,
                  decoration: webInputDecoration(
                    'Buscar ruta',
                    hint: 'Nombre, zona o visitador',
                  ).copyWith(prefixIcon: const Icon(Icons.search_rounded)),
                  onSubmitted: (_) => _load(),
                ),
              ),
              WebFieldBox(
                child: DropdownButtonFormField<int?>(
                  value: _zoneFilter,
                  decoration: webInputDecoration('Zona'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Todas las zonas'),
                    ),
                    ...mapList(_catalog['zonas']).map(
                      (zone) => DropdownMenuItem<int?>(
                        value: intValue(zone['zona_id']),
                        child: Text(zone['zona_nombre']?.toString() ?? '-'),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _zoneFilter = value);
                    _load();
                  },
                ),
              ),
              WebFieldBox(
                child: DropdownButtonFormField<int?>(
                  value: _visitadorFilter,
                  decoration: webInputDecoration('Visitador'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Todos'),
                    ),
                    ...mapList(_catalog['visitadores']).map(
                      (user) => DropdownMenuItem<int?>(
                        value: intValue(user['usu_id']),
                        child: Text(user['usu_nombre']?.toString() ?? '-'),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _visitadorFilter = value);
                    _load();
                  },
                ),
              ),
              WebFieldBox(
                child: DropdownButtonFormField<int?>(
                  value: _stateFilter,
                  decoration: webInputDecoration('Estado'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Todos'),
                    ),
                    ...mapList(_catalog['estados']).map(
                      (state) => DropdownMenuItem<int?>(
                        value: intValue(state['est_id']),
                        child: Text(state['est_nombre']?.toString() ?? '-'),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _stateFilter = value);
                    _load();
                  },
                ),
              ),
              WebPrimaryButton(
                label: 'Actualizar',
                icon: Icons.refresh_rounded,
                filled: false,
                onPressed: _load,
              ),
            ],
          ),
          const SizedBox(height: 18),
          WebMetricGrid(
            metrics: [
              WebMetric(
                label: 'Rutas del día',
                value: '${_routes.length}',
                icon: Icons.route_rounded,
              ),
              WebMetric(
                label: 'Rutas activas',
                value: '$active',
                icon: Icons.check_circle_rounded,
                color: SigmaColors.success,
              ),
              WebMetric(
                label: 'Puntos planificados',
                value: '$points',
                icon: Icons.location_on_rounded,
                color: SigmaColors.secondary,
              ),
              WebMetric(
                label: 'Visitadores asignados',
                value: '$visitadores',
                icon: Icons.badge_rounded,
                color: SigmaColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 18),
          WebTableContainer(
            title: 'Rutas programadas para ${_dateFormat.format(_date)}',
            child: WebAsyncBody(
              loading: _loading,
              error: _error,
              empty: _routes.isEmpty,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Ruta')),
                    DataColumn(label: Text('Zona')),
                    DataColumn(label: Text('Supervisor')),
                    DataColumn(label: Text('Visitador')),
                    DataColumn(label: Text('Puntos')),
                    DataColumn(label: Text('Estado')),
                    DataColumn(label: Text('Acciones')),
                  ],
                  rows: _routes.map(_routeRow).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _routeRow(Map<String, dynamic> route) {
    final pointCount =
        intValue(route['detalles_count']) ?? mapList(route['detalles']).length;
    return DataRow(
      cells: [
        DataCell(
          SizedBox(
            width: 205,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route['ruta_nombre']?.toString() ??
                      'Ruta ${route['ruta_id'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _dateText(route['ruta_fecha']),
                  style: const TextStyle(
                    color: SigmaColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(Text(nestedText(route, 'zona.zona_nombre'))),
        DataCell(Text(nestedText(route, 'supervisor.usu_nombre'))),
        DataCell(Text(nestedText(route, 'visitador.usu_nombre'))),
        DataCell(Text('$pointCount')),
        DataCell(
          WebStatusChip(
            label: nestedText(route, 'estado.est_nombre'),
            active: intValue(route['est_id']) == 1,
          ),
        ),
        DataCell(
          PopupMenuButton<String>(
            tooltip: 'Acciones de la ruta',
            onSelected: (value) {
              if (value == 'view') {
                _showRouteDetails(route);
              } else if (value == 'edit') {
                _openDialog(route);
              } else if (value == 'delete') {
                _deleteRoute(route);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'view',
                child: ListTile(
                  leading: Icon(Icons.visibility_outlined),
                  title: Text('Ver ruta'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (_canEdit)
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_road_rounded),
                    title: Text('Editar ruta'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              if (_canEdit)
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: SigmaColors.danger,
                    ),
                    title: Text(
                      'Eliminar ruta',
                      style: TextStyle(color: SigmaColors.danger),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.more_horiz_rounded),
            ),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _routeClients(Map<String, dynamic> route) {
    final direct = mapList(route['clientes']);
    if (direct.isNotEmpty) return direct;

    return mapList(route['detalles'])
        .map((detail) => mapValue(detail['cliente']))
        .where((client) => client.isNotEmpty)
        .toList();
  }

  Future<void> _showRouteDetails(Map<String, dynamic> route) async {
    final clients = _routeClients(route);
    final pointCount = intValue(route['detalles_count']) ?? clients.length;

    await showWebDetailDialog(
      context: context,
      title:
          route['ruta_nombre']?.toString() ??
          'Ruta ${route['ruta_id']?.toString() ?? ''}',
      subtitle: _canEdit
          ? 'Ficha de consulta de la planificación y sus responsables.'
          : 'Consulta operativa de la ruta asignada al equipo.',
      icon: Icons.route_outlined,
      width: 900,
      editLabel: 'Editar ruta',
      onEdit: _canEdit ? () => _openDialog(route) : null,
      sections: [
        WebDetailSection(
          title: 'Planificación',
          icon: Icons.calendar_month_outlined,
          items: [
            WebDetailItem(
              label: 'Fecha',
              value: _dateText(route['ruta_fecha']),
              icon: Icons.event_outlined,
            ),
            WebDetailItem(
              label: 'Zona',
              value: nestedText(route, 'zona.zona_nombre'),
              icon: Icons.map_outlined,
            ),
            WebDetailItem(
              label: 'Estado',
              value: nestedText(route, 'estado.est_nombre'),
              icon: Icons.toggle_on_outlined,
            ),
            WebDetailItem(
              label: 'Puntos planificados',
              value: '$pointCount',
              icon: Icons.location_on_outlined,
            ),
          ],
        ),
        WebDetailSection(
          title: 'Responsables',
          icon: Icons.groups_outlined,
          items: [
            WebDetailItem(
              label: 'Supervisor',
              value: nestedText(
                route,
                'supervisor.usu_nombre',
                'Sin supervisor',
              ),
              icon: Icons.supervisor_account_outlined,
            ),
            WebDetailItem(
              label: 'Visitador médico',
              value: nestedText(route, 'visitador.usu_nombre', 'Sin visitador'),
              icon: Icons.badge_outlined,
            ),
            WebDetailItem(
              label: 'Código interno',
              value: route['ruta_id']?.toString() ?? '-',
              icon: Icons.tag_rounded,
            ),
          ],
        ),
        WebDetailSection(
          title: 'Puntos de visita',
          subtitle: clients.isEmpty
              ? 'No hay puntos disponibles en la respuesta actual.'
              : 'Ubicación geográfica de los puntos asociados a la ruta.',
          icon: Icons.location_on_outlined,
          child: clients.isEmpty
              ? const WebInfoBanner(
                  text:
                      'La ruta no incluye el detalle de clientes en esta consulta.',
                  icon: Icons.info_outline_rounded,
                  color: SigmaColors.warning,
                )
              : SizedBox(
                  height: 350,
                  child: WebRoutePreviewMap(clients: clients),
                ),
        ),
      ],
    );
  }

  Future<void> _pickFilterDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (selected == null) return;
    setState(() => _date = selected);
    await _load();
  }

  Future<void> _openDialog([Map<String, dynamic>? route]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RouteFormDialog(
        provider: _provider,
        catalog: _catalog,
        route: route,
        initialDate: route == null ? _date : null,
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _deleteRoute(Map<String, dynamic> route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar ruta'),
        content: Text(
          '¿Desea eliminar la ruta "${route['ruta_nombre'] ?? route['ruta_id']}"? '
          'Solo será posible si todavía no tiene una jornada relacionada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: SigmaColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _provider.delete('/rutas/${route['ruta_id']}');
      if (!mounted) return;
      showWebMessage(context, 'Ruta eliminada correctamente.');
      await _load();
    } catch (error) {
      if (mounted) showWebMessage(context, error.toString(), error: true);
    }
  }

  String _dateText(dynamic raw) {
    final value = raw?.toString() ?? '';
    return value.length >= 10 ? value.substring(0, 10) : value;
  }
}

class _RouteFormDialog extends StatefulWidget {
  const _RouteFormDialog({
    required this.provider,
    required this.catalog,
    this.route,
    this.initialDate,
  });

  final WebApiProvider provider;
  final Map<String, dynamic> catalog;
  final Map<String, dynamic>? route;
  final DateTime? initialDate;

  @override
  State<_RouteFormDialog> createState() => _RouteFormDialogState();
}

class _RouteFormDialogState extends State<_RouteFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _dateFormat = DateFormat('yyyy-MM-dd');
  late final TextEditingController _name;
  late final TextEditingController _observation;

  int? _companyId;
  int? _zoneId;
  int? _supervisorId;
  int? _visitadorId;
  int? _stateId;
  late DateTime _date;
  List<int> _selectedClientIds = [];
  bool _saving = false;

  bool get _editing => widget.route != null;

  List<Map<String, dynamic>> get _supervisors =>
      mapList(widget.catalog['supervisores']);

  List<Map<String, dynamic>> get _zones {
    final all = mapList(widget.catalog['zonas']);
    if (_supervisorId == null) return all;
    return all
        .where((zone) => intValue(zone['supervisor_id']) == _supervisorId)
        .toList();
  }

  List<Map<String, dynamic>> get _visitadores {
    final all = mapList(widget.catalog['visitadores']);
    if (_supervisorId == null) return all;
    return all
        .where((user) => intValue(user['supervisor_id']) == _supervisorId)
        .toList();
  }

  List<Map<String, dynamic>> get _clients => mapList(
    widget.catalog['clientes'],
  ).where((client) => intValue(client['zona_id']) == _zoneId).toList();

  @override
  void initState() {
    super.initState();
    final route = widget.route ?? <String, dynamic>{};
    _name = TextEditingController(text: route['ruta_nombre']?.toString() ?? '');
    _observation = TextEditingController(
      text: route['observacion']?.toString() ?? '',
    );
    _companyId = intValue(route['emp_id']) ?? _firstId('empresas', 'emp_id');
    _supervisorId =
        intValue(route['supervisor_id']) ?? _firstId('supervisores', 'usu_id');
    _zoneId = intValue(route['zona_id']);
    _visitadorId = intValue(route['visitador_id']);
    _stateId = intValue(route['est_id']) ?? 1;
    _date =
        _parseDate(route['ruta_fecha']) ?? widget.initialDate ?? DateTime.now();
    _selectedClientIds = mapList(
      route['detalles'],
    ).map((item) => intValue(item['cliente_id'])).whereType<int>().toList();

    _normalizeAssignments();
  }

  int? _firstId(String key, String idKey) {
    final items = mapList(widget.catalog[key]);
    return items.isEmpty ? null : intValue(items.first[idKey]);
  }

  DateTime? _parseDate(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return null;
    return DateTime.tryParse(text.length >= 10 ? text.substring(0, 10) : text);
  }

  void _normalizeAssignments() {
    if (_zoneId == null && _zones.isNotEmpty) {
      _zoneId = intValue(_zones.first['zona_id']);
    }
    if (!_zones.any((zone) => intValue(zone['zona_id']) == _zoneId)) {
      _zoneId = _zones.isEmpty ? null : intValue(_zones.first['zona_id']);
      _selectedClientIds.clear();
    }
    if (_visitadorId == null && _visitadores.isNotEmpty) {
      _visitadorId = intValue(_visitadores.first['usu_id']);
    }
    if (!_visitadores.any((user) => intValue(user['usu_id']) == _visitadorId)) {
      _visitadorId = _visitadores.isEmpty
          ? null
          : intValue(_visitadores.first['usu_id']);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _observation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 22),
      title: WebDialogHeader(
        title: _editing ? 'Editar ruta' : 'Nueva ruta',
        subtitle: _editing
            ? 'Actualiza la planificación y los puntos de visita asignados.'
            : 'Define responsables, fecha y puntos de visita antes de guardar.',
        icon: Icons.alt_route_rounded,
      ),
      content: SizedBox(
        width: 1220,
        height: 780,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const WebFormSectionTitle(
                title: 'Datos de la ruta',
                subtitle: 'Identifica la planificación y la fecha de trabajo.',
                icon: Icons.event_note_outlined,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _name,
                      decoration: webInputDecoration('Nombre de la ruta'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: webInputDecoration('Fecha').copyWith(
                          suffixIcon: const Icon(Icons.calendar_month_rounded),
                        ),
                        child: Text(_dateFormat.format(_date)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _stateId,
                      decoration: webInputDecoration('Estado'),
                      items: mapList(widget.catalog['estados'])
                          .map(
                            (state) => DropdownMenuItem<int>(
                              value: intValue(state['est_id']),
                              child: Text(
                                state['est_nombre']?.toString() ?? '-',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _stateId = value),
                      validator: (value) =>
                          value == null ? 'Campo requerido' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const WebFormSectionTitle(
                title: 'Asignación',
                subtitle: 'Selecciona supervisor, zona y visitador médico.',
                icon: Icons.groups_2_outlined,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _supervisorId,
                      decoration: webInputDecoration('Supervisor'),
                      items: _supervisors
                          .map(
                            (user) => DropdownMenuItem<int>(
                              value: intValue(user['usu_id']),
                              child: Text(
                                user['usu_nombre']?.toString() ?? '-',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() {
                        _supervisorId = value;
                        _zoneId = null;
                        _visitadorId = null;
                        _selectedClientIds.clear();
                        _normalizeAssignments();
                      }),
                      validator: (value) =>
                          value == null ? 'Campo requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _zoneId,
                      decoration: webInputDecoration('Zona'),
                      items: _zones
                          .map(
                            (zone) => DropdownMenuItem<int>(
                              value: intValue(zone['zona_id']),
                              child: Text(
                                zone['zona_nombre']?.toString() ?? '-',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() {
                        _zoneId = value;
                        _selectedClientIds.clear();
                      }),
                      validator: (value) =>
                          value == null ? 'Campo requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _visitadorId,
                      decoration: webInputDecoration('Visitador médico'),
                      items: _visitadores
                          .map(
                            (user) => DropdownMenuItem<int>(
                              value: intValue(user['usu_id']),
                              child: Text(
                                user['usu_nombre']?.toString() ?? '-',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _visitadorId = value),
                      validator: (value) =>
                          value == null ? 'Campo requerido' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _observation,
                maxLines: 2,
                decoration: webInputDecoration('Observación de la ruta'),
              ),
              const SizedBox(height: 18),
              const WebFormSectionTitle(
                title: 'Puntos de visita',
                subtitle:
                    'Selecciona los clientes que formarán parte de la ruta. El orden operativo se determinará automáticamente durante la jornada.',
                icon: Icons.pin_drop_outlined,
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 4, child: _availableClientsPanel()),
                    const SizedBox(width: 16),
                    Expanded(flex: 6, child: _selectedClientsPanel()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        WebPrimaryButton(
          label: _editing ? 'Guardar cambios' : 'Registrar ruta',
          icon: Icons.save_outlined,
          busy: _saving,
          onPressed: _save,
        ),
      ],
    );
  }

  Widget _availableClientsPanel() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Puntos disponibles (${_clients.length})',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _clients.isEmpty
                ? const Center(
                    child: Text(
                      'Seleccione una zona con clientes activos.',
                      style: TextStyle(color: SigmaColors.muted),
                    ),
                  )
                : ListView.builder(
                    itemCount: _clients.length,
                    itemBuilder: (context, index) {
                      final client = _clients[index];
                      final id = intValue(client['cliente_id']);
                      if (id == null) return const SizedBox.shrink();
                      final selected = _selectedClientIds.contains(id);
                      return CheckboxListTile(
                        value: selected,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          client['cliente_nombre']?.toString() ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          nestedText(client, 'tipo_cliente.tc_nombre'),
                        ),
                        onChanged: (checked) => setState(() {
                          if (checked == true) {
                            _selectedClientIds.add(id);
                          } else {
                            _selectedClientIds.remove(id);
                          }
                        }),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _selectedClientsPanel() {
    final selectedClients = _selectedClientIds
        .map(_clientById)
        .whereType<Map<String, dynamic>>()
        .toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Puntos seleccionados (${_selectedClientIds.length})',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (_selectedClientIds.isNotEmpty)
                TextButton.icon(
                  onPressed: () => setState(_selectedClientIds.clear),
                  icon: const Icon(Icons.clear_all_rounded, size: 18),
                  label: const Text('Limpiar'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _selectedClientIds.isEmpty
                ? const _EmptySelectedRoutePoints()
                : Column(
                    children: [
                      Expanded(
                        child: WebRoutePreviewMap(clients: selectedClients),
                      ),
                      const SizedBox(height: 10),
                      const WebInfoBanner(
                        text:
                            'SIGPRED utilizará estos puntos durante la jornada. '
                            'El visitador verá la sugerencia operativa según su ubicación; '
                            'la selección realizada aquí no representa un orden de recorrido.',
                        icon: Icons.auto_awesome_outlined,
                        color: SigmaColors.secondary,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _clientById(int id) {
    for (final client in mapList(widget.catalog['clientes'])) {
      if (intValue(client['cliente_id']) == id) return client;
    }
    return null;
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (selected != null) setState(() => _date = selected);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedClientIds.isEmpty) {
      showWebMessage(
        context,
        'Debe seleccionar al menos un punto de visita.',
        error: true,
      );
      return;
    }

    setState(() => _saving = true);
    final body = <String, dynamic>{
      'emp_id': _companyId,
      'zona_id': _zoneId,
      'supervisor_id': _supervisorId,
      'visitador_id': _visitadorId,
      'est_id': _stateId,
      'ruta_nombre': _name.text.trim().isEmpty ? null : _name.text.trim(),
      'ruta_fecha': _dateFormat.format(_date),
      'observacion': _observation.text.trim().isEmpty
          ? null
          : _observation.text.trim(),
      'detalles': [
        for (var index = 0; index < _selectedClientIds.length; index++)
          {'cliente_id': _selectedClientIds[index], 'orden_visita': index + 1},
      ],
    };

    try {
      if (_editing) {
        await widget.provider.put('/rutas/${widget.route!['ruta_id']}', body);
      } else {
        await widget.provider.post('/rutas', body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) showWebMessage(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _EmptySelectedRoutePoints extends StatelessWidget {
  const _EmptySelectedRoutePoints();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: SigmaColors.primary.withOpacity(.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_location_alt_outlined,
                color: SigmaColors.primary,
                size: 27,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Selecciona puntos de visita',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            const SizedBox(height: 5),
            Text(
              'Marca clientes en la lista de la izquierda. '
              'Aquí verás únicamente su ubicación en el mapa.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: SigmaColors.muted,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
