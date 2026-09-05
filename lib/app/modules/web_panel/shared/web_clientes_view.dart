import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/providers/web_api_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../utils/app_theme.dart';
import '../layout/web_panel_shell.dart';
import 'web_management_widgets.dart';
import 'web_clients_overview_map.dart';
import 'web_client_location_picker.dart';
import 'web_widgets.dart';

class WebClientesView extends StatefulWidget {
  const WebClientesView({
    super.key,
    this.activeRoute = Routes.webAdminClientes,
    this.title = 'Clientes y puntos de visita',
    this.subtitle =
        'Administra farmacias, consultorios, clínicas y puntos de visita.',
  });

  final String activeRoute;
  final String title;
  final String subtitle;

  @override
  State<WebClientesView> createState() => _WebClientesViewState();
}

class _WebClientesViewState extends State<WebClientesView> {
  final _provider = Get.find<WebApiProvider>();
  final _searchController = TextEditingController();

  Map<String, dynamic> _catalog = {};
  List<Map<String, dynamic>> _clients = [];
  bool _loading = true;
  String? _error;
  int? _zoneFilter;
  int? _typeFilter;
  int? _stateFilter;
  bool _showMap = false;

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
        _provider.getMap('/clientes', {
          'per_page': 100,
          if (_searchController.text.trim().isNotEmpty)
            'search': _searchController.text.trim(),
          if (_zoneFilter != null) 'zona_id': _zoneFilter,
          if (_typeFilter != null) 'tc_id': _typeFilter,
          if (_stateFilter != null) 'est_id': _stateFilter,
        }),
      ]);

      if (!mounted) return;
      setState(() {
        _catalog = results[0];
        _clients = mapList(results[1]['data']);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _clients.where((c) => intValue(c['est_id']) == 1).length;
    final withGps = _clients
        .where(
          (c) =>
              doubleValue(c['cliente_lat']) != null &&
              doubleValue(c['cliente_lng']) != null,
        )
        .length;
    final zones = _clients
        .map((c) => intValue(c['zona_id']))
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
            title: 'Filtro de clientes',
            trailing: _canEdit
                ? WebPrimaryButton(
                    label: 'Nuevo cliente',
                    onPressed: () => _openDialog(),
                  )
                : null,
            children: [
              WebFieldBox(
                width: 330,
                child: TextField(
                  controller: _searchController,
                  decoration: webInputDecoration(
                    'Buscar cliente',
                    hint: 'Nombre, contacto, teléfono o dirección',
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
                  value: _typeFilter,
                  decoration: webInputDecoration('Tipo de cliente'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Todos los tipos'),
                    ),
                    ...mapList(_catalog['tipos_cliente']).map(
                      (type) => DropdownMenuItem<int?>(
                        value: intValue(type['tc_id']),
                        child: Text(type['tc_nombre']?.toString() ?? '-'),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _typeFilter = value);
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
                label: 'Clientes cargados',
                value: '${_clients.length}',
                icon: Icons.groups_2_rounded,
              ),
              WebMetric(
                label: 'Clientes activos',
                value: '$active',
                icon: Icons.verified_rounded,
                color: SigmaColors.success,
              ),
              WebMetric(
                label: 'Con coordenadas GPS',
                value: '$withGps',
                icon: Icons.location_on_rounded,
                color: SigmaColors.secondary,
              ),
              WebMetric(
                label: 'Zonas representadas',
                value: '$zones',
                icon: Icons.map_rounded,
                color: SigmaColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  _showMap ? 'Vista geográfica' : 'Listado de clientes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    icon: Icon(Icons.view_list_rounded),
                    label: Text('Lista'),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    icon: Icon(Icons.map_outlined),
                    label: Text('Mapa'),
                  ),
                ],
                selected: {_showMap},
                onSelectionChanged: (values) {
                  setState(() => _showMap = values.first);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_showMap)
            SizedBox(
              height: 560,
              child: WebClientsOverviewMap(clients: _clients),
            )
          else
            WebTableContainer(
              title: 'Listado de clientes y puntos de visita',
              child: WebAsyncBody(
                loading: _loading,
                error: _error,
                empty: _clients.isEmpty,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Cliente')),
                      DataColumn(label: Text('Zona')),
                      DataColumn(label: Text('Contacto')),
                      DataColumn(label: Text('Dirección')),
                      DataColumn(label: Text('Ubicación')),
                      DataColumn(label: Text('Estado')),
                      DataColumn(label: Text('Acciones')),
                    ],
                    rows: _clients.map(_clientRow).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  DataRow _clientRow(Map<String, dynamic> client) {
    final lat = doubleValue(client['cliente_lat']);
    final lng = doubleValue(client['cliente_lng']);
    final hasLocation = lat != null && lng != null;
    final active = intValue(client['est_id']) == 1;

    return DataRow(
      cells: [
        DataCell(
          SizedBox(
            width: 215,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client['cliente_nombre']?.toString() ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  nestedText(client, 'tipo_cliente.tc_nombre'),
                  style: const TextStyle(
                    color: SigmaColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(Text(nestedText(client, 'zona.zona_nombre'))),
        DataCell(
          SizedBox(
            width: 175,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client['cliente_contacto']?.toString() ?? 'Sin contacto',
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  client['cliente_telefono']?.toString() ?? '',
                  style: const TextStyle(
                    color: SigmaColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 235,
            child: Text(
              client['cliente_dir']?.toString() ?? 'Sin dirección registrada',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: (hasLocation ? SigmaColors.success : SigmaColors.warning)
                  .withOpacity(.08),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasLocation
                      ? Icons.location_on_rounded
                      : Icons.location_off_outlined,
                  size: 15,
                  color: hasLocation
                      ? SigmaColors.success
                      : SigmaColors.warning,
                ),
                const SizedBox(width: 5),
                Text(
                  hasLocation ? 'Ubicación lista' : 'Sin ubicación',
                  style: TextStyle(
                    color: hasLocation
                        ? SigmaColors.success
                        : SigmaColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          WebStatusChip(
            label: nestedText(client, 'estado.est_nombre'),
            active: active,
          ),
        ),
        DataCell(
          PopupMenuButton<String>(
            tooltip: 'Acciones del cliente',
            onSelected: (value) {
              if (value == 'view') {
                _showClientDetails(client);
              } else if (value == 'edit') {
                _openDialog(client);
              } else if (value == 'state') {
                _toggleState(client);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'view',
                child: ListTile(
                  leading: Icon(Icons.visibility_outlined),
                  title: Text('Ver cliente'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (_canEdit)
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Editar cliente'),
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

  Future<void> _showClientDetails(Map<String, dynamic> client) async {
    final lat = doubleValue(client['cliente_lat']);
    final lng = doubleValue(client['cliente_lng']);
    final hasLocation = lat != null && lng != null;

    await showWebDetailDialog(
      context: context,
      title: client['cliente_nombre']?.toString() ?? 'Cliente',
      subtitle: 'Ficha de consulta del cliente y punto de visita.',
      icon: Icons.storefront_outlined,
      width: 860,
      editLabel: 'Editar cliente',
      onEdit: _canEdit ? () => _openDialog(client) : null,
      sections: [
        WebDetailSection(
          title: 'Información general',
          icon: Icons.business_outlined,
          items: [
            WebDetailItem(
              label: 'Tipo de cliente',
              value: nestedText(client, 'tipo_cliente.tc_nombre'),
              icon: Icons.category_outlined,
            ),
            WebDetailItem(
              label: 'Zona',
              value: nestedText(client, 'zona.zona_nombre'),
              icon: Icons.map_outlined,
            ),
            WebDetailItem(
              label: 'Estado',
              value: nestedText(client, 'estado.est_nombre'),
              icon: Icons.toggle_on_outlined,
            ),
            WebDetailItem(
              label: 'Código interno',
              value: client['cliente_id']?.toString() ?? '-',
              icon: Icons.tag_rounded,
            ),
          ],
        ),
        WebDetailSection(
          title: 'Contacto',
          icon: Icons.contact_phone_outlined,
          items: [
            WebDetailItem(
              label: 'Persona de contacto',
              value: client['cliente_contacto']?.toString() ?? 'Sin contacto',
              icon: Icons.person_outline_rounded,
            ),
            WebDetailItem(
              label: 'Teléfono',
              value: client['cliente_telefono']?.toString() ?? 'Sin teléfono',
              icon: Icons.phone_outlined,
            ),
          ],
        ),
        WebDetailSection(
          title: 'Dirección',
          icon: Icons.location_city_outlined,
          items: [
            WebDetailItem(
              label: 'Dirección',
              value: client['cliente_dir']?.toString() ?? 'Sin dirección',
              icon: Icons.signpost_outlined,
            ),
            WebDetailItem(
              label: 'Referencia',
              value:
                  client['cliente_referencia']?.toString() ?? 'Sin referencia',
              icon: Icons.near_me_outlined,
            ),
          ],
        ),
        WebDetailSection(
          title: 'Ubicación',
          subtitle: hasLocation
              ? 'Punto utilizado para rutas y seguimiento operativo.'
              : 'Este cliente todavía no tiene una ubicación registrada.',
          icon: hasLocation
              ? Icons.location_on_outlined
              : Icons.location_off_outlined,
          child: hasLocation
              ? SizedBox(
                  height: 330,
                  child: WebClientsOverviewMap(clients: [client]),
                )
              : const WebInfoBanner(
                  text:
                      'Sin ubicación. Un Administrador puede editar el cliente y marcar el punto en el mapa.',
                  icon: Icons.location_off_outlined,
                  color: SigmaColors.warning,
                ),
        ),
      ],
    );
  }

  Future<void> _openDialog([Map<String, dynamic>? client]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ClientFormDialog(
        provider: _provider,
        catalog: _catalog,
        client: client,
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _toggleState(Map<String, dynamic> client) async {
    final next = intValue(client['est_id']) == 1 ? 2 : 1;
    try {
      await _provider.put('/clientes/${client['cliente_id']}', {
        'est_id': next,
      });
      if (!mounted) return;
      showWebMessage(
        context,
        next == 1 ? 'Cliente activado.' : 'Cliente desactivado.',
      );
      await _load();
    } catch (error) {
      if (mounted) showWebMessage(context, error.toString(), error: true);
    }
  }
}

class _ClientFormDialog extends StatefulWidget {
  const _ClientFormDialog({
    required this.provider,
    required this.catalog,
    this.client,
  });

  final WebApiProvider provider;
  final Map<String, dynamic> catalog;
  final Map<String, dynamic>? client;

  @override
  State<_ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends State<_ClientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _contact;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _reference;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;

  int? _companyId;
  int? _zoneId;
  int? _typeId;
  int? _stateId;
  bool _saving = false;

  bool get _editing => widget.client != null;

  @override
  void initState() {
    super.initState();
    final client = widget.client ?? <String, dynamic>{};
    _name = TextEditingController(
      text: client['cliente_nombre']?.toString() ?? '',
    );
    _contact = TextEditingController(
      text: client['cliente_contacto']?.toString() ?? '',
    );
    _phone = TextEditingController(
      text: client['cliente_telefono']?.toString() ?? '',
    );
    _address = TextEditingController(
      text: client['cliente_dir']?.toString() ?? '',
    );
    _reference = TextEditingController(
      text: client['cliente_referencia']?.toString() ?? '',
    );
    _latitude = TextEditingController(
      text: client['cliente_lat']?.toString() ?? '',
    );
    _longitude = TextEditingController(
      text: client['cliente_lng']?.toString() ?? '',
    );

    _companyId = intValue(client['emp_id']) ?? _firstId('empresas', 'emp_id');
    _zoneId = intValue(client['zona_id']) ?? _firstId('zonas', 'zona_id');
    _typeId = intValue(client['tc_id']) ?? _firstId('tipos_cliente', 'tc_id');
    _stateId = intValue(client['est_id']) ?? 1;
  }

  int? _firstId(String key, String idKey) {
    final items = mapList(widget.catalog[key]);
    return items.isEmpty ? null : intValue(items.first[idKey]);
  }

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _phone.dispose();
    _address.dispose();
    _reference.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentName = _name.text.trim();

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 22),
      title: WebDialogHeader(
        title: _editing ? 'Editar cliente' : 'Registrar cliente',
        subtitle: _editing
            ? currentName.isEmpty
                  ? 'Modifica la información del cliente existente.'
                  : 'Estás modificando la información de $currentName.'
            : 'Registra un nuevo punto de visita y marca su ubicación en el mapa.',
        icon: _editing ? Icons.edit_location_alt_outlined : Icons.add_business,
      ),
      content: SizedBox(
        width: 960,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 720),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WebFormSectionCard(
                    title: 'Información general',
                    subtitle:
                        'Identifica el punto de visita y su clasificación dentro de SIGPRED.',
                    icon: Icons.business_outlined,
                    child: Column(
                      children: [
                        _responsivePair(
                          TextFormField(
                            controller: _name,
                            autofocus: !_editing,
                            decoration: webInputDecoration(
                              'Nombre del cliente',
                              hint: 'Ej. Farmacia Central',
                            ),
                            validator: _required,
                          ),
                          DropdownButtonFormField<int>(
                            value: _typeId,
                            isExpanded: true,
                            decoration: webInputDecoration('Tipo de cliente'),
                            items: mapList(widget.catalog['tipos_cliente'])
                                .map(
                                  (type) => DropdownMenuItem<int>(
                                    value: intValue(type['tc_id']),
                                    child: Text(
                                      type['tc_nombre']?.toString() ?? '-',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _typeId = value),
                            validator: (value) =>
                                value == null ? 'Campo requerido' : null,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _responsivePair(
                          DropdownButtonFormField<int>(
                            value: _zoneId,
                            isExpanded: true,
                            decoration: webInputDecoration('Zona'),
                            items: mapList(widget.catalog['zonas'])
                                .map(
                                  (zone) => DropdownMenuItem<int>(
                                    value: intValue(zone['zona_id']),
                                    child: Text(
                                      zone['zona_nombre']?.toString() ?? '-',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _zoneId = value),
                            validator: (value) =>
                                value == null ? 'Campo requerido' : null,
                          ),
                          DropdownButtonFormField<int>(
                            value: _stateId,
                            isExpanded: true,
                            decoration: webInputDecoration('Estado'),
                            items: mapList(widget.catalog['estados'])
                                .map(
                                  (state) => DropdownMenuItem<int>(
                                    value: intValue(state['est_id']),
                                    child: Text(
                                      state['est_nombre']?.toString() ?? '-',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _stateId = value),
                            validator: (value) =>
                                value == null ? 'Campo requerido' : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  WebFormSectionCard(
                    title: 'Contacto',
                    subtitle:
                        'Datos útiles para comunicarse con el establecimiento o responsable.',
                    icon: Icons.contact_phone_outlined,
                    child: _responsivePair(
                      TextFormField(
                        controller: _contact,
                        decoration: webInputDecoration(
                          'Persona de contacto',
                          hint: 'Nombre del responsable',
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      TextFormField(
                        controller: _phone,
                        decoration:
                            webInputDecoration(
                              'Teléfono',
                              hint: 'Número de contacto',
                            ).copyWith(
                              prefixIcon: const Icon(Icons.phone_outlined),
                            ),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  WebFormSectionCard(
                    title: 'Dirección',
                    subtitle:
                        'Describe cómo encontrar el punto antes de marcarlo en el mapa.',
                    icon: Icons.signpost_outlined,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _address,
                          decoration: webInputDecoration(
                            'Dirección',
                            hint: 'Avenida, calle, número o zona',
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _reference,
                          decoration: webInputDecoration(
                            'Referencia',
                            hint: 'Ej. frente al hospital, esquina...',
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  WebFormSectionCard(
                    title: 'Ubicación',
                    subtitle:
                        'Marca el punto exacto que se utilizará en rutas y seguimiento. Las coordenadas quedan como información técnica secundaria.',
                    icon: Icons.location_on_outlined,
                    child: WebClientLocationPicker(
                      latitudeController: _latitude,
                      longitudeController: _longitude,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        WebPrimaryButton(
          label: _editing ? 'Guardar cambios' : 'Registrar cliente',
          icon: _editing ? Icons.save_outlined : Icons.add_business_outlined,
          busy: _saving,
          onPressed: _save,
        ),
      ],
    );
  }

  Widget _responsivePair(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 660) {
          return Column(children: [first, const SizedBox(height: 14), second]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 14),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'Campo requerido' : null;

  bool _coordinatesAreValid() {
    if (_latitude.text.trim().isEmpty && _longitude.text.trim().isEmpty) {
      return true;
    }
    final lat = _numberOrNull(_latitude.text);
    final lng = _numberOrNull(_longitude.text);
    return lat != null &&
        lng != null &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_coordinatesAreValid()) {
      showWebMessage(
        context,
        'La ubicación guardada no es válida. Marca nuevamente el punto en el mapa.',
        error: true,
      );
      return;
    }

    setState(() => _saving = true);

    final body = <String, dynamic>{
      'emp_id': _companyId,
      'zona_id': _zoneId,
      'tc_id': _typeId,
      'est_id': _stateId,
      'cliente_nombre': _name.text.trim(),
      'cliente_contacto': _emptyToNull(_contact.text),
      'cliente_telefono': _emptyToNull(_phone.text),
      'cliente_dir': _emptyToNull(_address.text),
      'cliente_referencia': _emptyToNull(_reference.text),
      'cliente_lat': _numberOrNull(_latitude.text),
      'cliente_lng': _numberOrNull(_longitude.text),
    };

    try {
      if (_editing) {
        await widget.provider.put(
          '/clientes/${widget.client!['cliente_id']}',
          body,
        );
      } else {
        await widget.provider.post('/clientes', body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) showWebMessage(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  double? _numberOrNull(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    return normalized.isEmpty ? null : double.tryParse(normalized);
  }
}
