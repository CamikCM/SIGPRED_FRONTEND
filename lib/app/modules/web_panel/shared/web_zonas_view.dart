import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/providers/web_api_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../utils/app_theme.dart';
import '../layout/web_panel_shell.dart';
import 'web_management_widgets.dart';
import 'web_widgets.dart';

class WebZonasView extends StatefulWidget {
  const WebZonasView({
    super.key,
    this.activeRoute = Routes.webAdminZonas,
    this.title = 'Gestión de Zonas',
    this.subtitle = 'Administra zonas operativas y supervisores responsables.',
  });

  final String activeRoute;
  final String title;
  final String subtitle;

  @override
  State<WebZonasView> createState() => _WebZonasViewState();
}

class _WebZonasViewState extends State<WebZonasView> {
  final _provider = Get.find<WebApiProvider>();
  final _searchController = TextEditingController();
  Map<String, dynamic> _catalog = {};
  List<Map<String, dynamic>> _zones = [];
  bool _loading = true;
  String? _error;
  int? _stateFilter;
  int? _supervisorFilter;

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
        _provider.getMap('/zonas', {
          'per_page': 100,
          if (_searchController.text.trim().isNotEmpty)
            'search': _searchController.text.trim(),
          if (_stateFilter != null) 'est_id': _stateFilter,
          if (_supervisorFilter != null) 'supervisor_id': _supervisorFilter,
        }),
      ]);
      if (!mounted) return;
      setState(() {
        _catalog = results[0];
        _zones = mapList(results[1]['data']);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _zones.where((z) => intValue(z['est_id']) == 1).length;
    final clients = _zones.fold<int>(
      0,
      (total, zone) => total + (intValue(zone['clientes_count']) ?? 0),
    );
    final routes = _zones.fold<int>(
      0,
      (total, zone) => total + (intValue(zone['rutas_count']) ?? 0),
    );

    return WebPanelShell(
      title: widget.title,
      subtitle: widget.subtitle,
      activeRoute: widget.activeRoute,
      child: Column(
        children: [
          WebFilterCard(
            title: 'Filtro de zonas',
            trailing: _canEdit
                ? WebPrimaryButton(
                    label: 'Nueva zona',
                    onPressed: () => _openDialog(),
                  )
                : null,
            children: [
              WebFieldBox(
                width: 320,
                child: TextField(
                  controller: _searchController,
                  decoration: webInputDecoration(
                    'Buscar zona',
                    hint: 'Nombre o descripción',
                  ).copyWith(prefixIcon: const Icon(Icons.search_rounded)),
                  onSubmitted: (_) => _load(),
                ),
              ),
              if (_canEdit)
                WebFieldBox(
                  child: DropdownButtonFormField<int?>(
                    value: _supervisorFilter,
                    decoration: webInputDecoration('Supervisor'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Todos'),
                      ),
                      ...mapList(_catalog['supervisores']).map(
                        (item) => DropdownMenuItem<int?>(
                          value: intValue(item['usu_id']),
                          child: Text(item['usu_nombre']?.toString() ?? '-'),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _supervisorFilter = value);
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
                      (item) => DropdownMenuItem<int?>(
                        value: intValue(item['est_id']),
                        child: Text(item['est_nombre']?.toString() ?? '-'),
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
                label: 'Zonas cargadas',
                value: '${_zones.length}',
                icon: Icons.map_rounded,
              ),
              WebMetric(
                label: 'Zonas activas',
                value: '$active',
                icon: Icons.check_circle_rounded,
                color: SigmaColors.success,
              ),
              WebMetric(
                label: 'Clientes relacionados',
                value: '$clients',
                icon: Icons.groups_rounded,
                color: SigmaColors.secondary,
              ),
              WebMetric(
                label: 'Rutas relacionadas',
                value: '$routes',
                icon: Icons.route_rounded,
                color: SigmaColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 18),
          WebTableContainer(
            title: 'Listado de zonas',
            child: WebAsyncBody(
              loading: _loading,
              error: _error,
              empty: _zones.isEmpty,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Zona')),
                    DataColumn(label: Text('Supervisor')),
                    DataColumn(label: Text('Clientes')),
                    DataColumn(label: Text('Rutas')),
                    DataColumn(label: Text('Estado')),
                    DataColumn(label: Text('Acciones')),
                  ],
                  rows: _zones.map(_zoneRow).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _zoneRow(Map<String, dynamic> zone) {
    final cells = <DataCell>[
      DataCell(
        SizedBox(
          width: 220,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                zone['zona_nombre']?.toString() ?? '-',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                zone['zona_descripcion']?.toString() ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: SigmaColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      DataCell(Text(nestedText(zone, 'supervisor.usu_nombre'))),
      DataCell(Text('${intValue(zone['clientes_count']) ?? 0}')),
      DataCell(Text('${intValue(zone['rutas_count']) ?? 0}')),
      DataCell(
        WebStatusChip(
          label: nestedText(zone, 'estado.est_nombre'),
          active: intValue(zone['est_id']) == 1,
        ),
      ),
    ];
    cells.add(
      DataCell(
        PopupMenuButton<String>(
          tooltip: 'Acciones de la zona',
          onSelected: (value) {
            if (value == 'view') {
              _showZoneDetails(zone);
            } else if (value == 'edit') {
              _openDialog(zone);
            } else if (value == 'state') {
              _toggleState(zone);
            }
          },
          itemBuilder: (context) {
            final active = intValue(zone['est_id']) == 1;
            return [
              const PopupMenuItem(
                value: 'view',
                child: ListTile(
                  leading: Icon(Icons.visibility_outlined),
                  title: Text('Ver zona'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (_canEdit)
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Editar zona'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              if (_canEdit)
                PopupMenuItem(
                  value: 'state',
                  child: ListTile(
                    leading: Icon(
                      active
                          ? Icons.block_rounded
                          : Icons.check_circle_outline_rounded,
                      color: active ? SigmaColors.danger : SigmaColors.success,
                    ),
                    title: Text(active ? 'Desactivar' : 'Activar'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ];
          },
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.more_horiz_rounded),
          ),
        ),
      ),
    );
    return DataRow(cells: cells);
  }

  Future<void> _showZoneDetails(Map<String, dynamic> zone) async {
    await showWebDetailDialog(
      context: context,
      title: zone['zona_nombre']?.toString() ?? 'Zona',
      subtitle: _canEdit
          ? 'Ficha de consulta y cobertura de la zona.'
          : 'Información operativa de la zona supervisada.',
      icon: Icons.map_outlined,
      editLabel: 'Editar zona',
      onEdit: _canEdit ? () => _openDialog(zone) : null,
      sections: [
        WebDetailSection(
          title: 'Información de la zona',
          icon: Icons.map_outlined,
          items: [
            WebDetailItem(
              label: 'Nombre',
              value: zone['zona_nombre']?.toString() ?? '-',
              icon: Icons.place_outlined,
            ),
            WebDetailItem(
              label: 'Estado',
              value: nestedText(zone, 'estado.est_nombre'),
              icon: Icons.toggle_on_outlined,
            ),
            WebDetailItem(
              label: 'Descripción',
              value: zone['zona_descripcion']?.toString() ?? 'Sin descripción',
              icon: Icons.notes_outlined,
            ),
            WebDetailItem(
              label: 'Código interno',
              value: zone['zona_id']?.toString() ?? '-',
              icon: Icons.tag_rounded,
            ),
          ],
        ),
        WebDetailSection(
          title: 'Cobertura operativa',
          icon: Icons.hub_outlined,
          items: [
            WebDetailItem(
              label: 'Supervisor',
              value: nestedText(
                zone,
                'supervisor.usu_nombre',
                'Sin supervisor',
              ),
              icon: Icons.supervisor_account_outlined,
            ),
            WebDetailItem(
              label: 'Clientes relacionados',
              value: '${intValue(zone['clientes_count']) ?? 0}',
              icon: Icons.groups_outlined,
            ),
            WebDetailItem(
              label: 'Rutas relacionadas',
              value: '${intValue(zone['rutas_count']) ?? 0}',
              icon: Icons.route_outlined,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openDialog([Map<String, dynamic>? zone]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _ZoneFormDialog(provider: _provider, catalog: _catalog, zone: zone),
    );
    if (saved == true) await _load();
  }

  Future<void> _toggleState(Map<String, dynamic> zone) async {
    final next = intValue(zone['est_id']) == 1 ? 2 : 1;
    try {
      await _provider.put('/zonas/${zone['zona_id']}', {'est_id': next});
      if (!mounted) return;
      showWebMessage(
        context,
        next == 1 ? 'Zona activada.' : 'Zona desactivada.',
      );
      await _load();
    } catch (error) {
      if (mounted) showWebMessage(context, error.toString(), error: true);
    }
  }
}

class _ZoneFormDialog extends StatefulWidget {
  const _ZoneFormDialog({
    required this.provider,
    required this.catalog,
    this.zone,
  });

  final WebApiProvider provider;
  final Map<String, dynamic> catalog;
  final Map<String, dynamic>? zone;

  @override
  State<_ZoneFormDialog> createState() => _ZoneFormDialogState();
}

class _ZoneFormDialogState extends State<_ZoneFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  int? _companyId;
  int? _stateId;
  int? _supervisorId;
  bool _saving = false;

  bool get _editing => widget.zone != null;

  @override
  void initState() {
    super.initState();
    final zone = widget.zone ?? <String, dynamic>{};
    _name = TextEditingController(text: zone['zona_nombre']?.toString() ?? '');
    _description = TextEditingController(
      text: zone['zona_descripcion']?.toString() ?? '',
    );
    _companyId = intValue(zone['emp_id']) ?? _firstId('empresas', 'emp_id');
    _stateId = intValue(zone['est_id']) ?? 1;
    _supervisorId = intValue(zone['supervisor_id']);
  }

  int? _firstId(String key, String idKey) {
    final items = mapList(widget.catalog[key]);
    return items.isEmpty ? null : intValue(items.first[idKey]);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 22),
      title: WebDialogHeader(
        title: _editing ? 'Editar zona' : 'Nueva zona',
        subtitle: _editing
            ? 'Actualiza la descripción, responsable o estado de la zona.'
            : 'Crea una zona y asigna al supervisor responsable.',
        icon: Icons.map_outlined,
      ),
      content: SizedBox(
        width: 680,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const WebFormSectionTitle(
                title: 'Información de la zona',
                subtitle:
                    'Nombre y descripción que identificarán el territorio.',
                icon: Icons.location_city_outlined,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: webInputDecoration('Nombre de la zona'),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: webInputDecoration('Descripción'),
              ),
              const SizedBox(height: 20),
              const WebFormSectionTitle(
                title: 'Responsable y estado',
                subtitle:
                    'Asigna quién supervisa la zona y controla su disponibilidad.',
                icon: Icons.supervisor_account_outlined,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _supervisorId,
                      decoration: webInputDecoration('Supervisor responsable'),
                      items: mapList(widget.catalog['supervisores'])
                          .map(
                            (item) => DropdownMenuItem<int>(
                              value: intValue(item['usu_id']),
                              child: Text(
                                item['usu_nombre']?.toString() ?? '-',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _supervisorId = value),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _stateId,
                      decoration: webInputDecoration('Estado'),
                      items: mapList(widget.catalog['estados'])
                          .map(
                            (item) => DropdownMenuItem<int>(
                              value: intValue(item['est_id']),
                              child: Text(
                                item['est_nombre']?.toString() ?? '-',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _stateId = value),
                    ),
                  ),
                ],
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
          label: _editing ? 'Guardar cambios' : 'Registrar zona',
          icon: Icons.save_outlined,
          busy: _saving,
          onPressed: _save,
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final body = {
      'emp_id': _companyId,
      'est_id': _stateId,
      'supervisor_id': _supervisorId,
      'zona_nombre': _name.text.trim(),
      'zona_descripcion': _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
    };
    try {
      if (_editing) {
        await widget.provider.put('/zonas/${widget.zone!['zona_id']}', body);
      } else {
        await widget.provider.post('/zonas', body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) showWebMessage(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
