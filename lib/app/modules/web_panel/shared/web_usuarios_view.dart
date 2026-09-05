import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/providers/web_api_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../utils/app_theme.dart';
import '../layout/web_panel_shell.dart';
import 'web_management_widgets.dart';
import 'web_widgets.dart';

class WebUsuariosView extends StatefulWidget {
  const WebUsuariosView({
    super.key,
    this.activeRoute = Routes.webAdminUsuarios,
  });

  final String activeRoute;

  @override
  State<WebUsuariosView> createState() => _WebUsuariosViewState();
}

class _WebUsuariosViewState extends State<WebUsuariosView> {
  final _provider = Get.find<WebApiProvider>();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic> _catalog = {};
  bool _loading = true;
  String? _error;
  int? _roleFilter;
  int? _stateFilter;

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
        _provider.getMap('/usuarios', {
          'per_page': 100,
          if (_searchController.text.trim().isNotEmpty)
            'search': _searchController.text.trim(),
          if (_roleFilter != null) 'rol_id': _roleFilter,
          if (_stateFilter != null) 'est_id': _stateFilter,
        }),
      ]);

      if (!mounted) return;
      setState(() {
        _catalog = results[0];
        _users = mapList(results[1]['data']);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _users.where((u) => intValue(u['est_id']) == 1).length;
    final supervisors = _users
        .where((u) => nestedText(u, 'rol.rol_nombre', '') == 'Supervisor')
        .length;
    final visitadores = _users
        .where((u) => nestedText(u, 'rol.rol_nombre', '') == 'Visitador médico')
        .length;

    return WebPanelShell(
      title: 'Usuarios',
      subtitle: 'Gestiona cuentas, roles, supervisores y estado del personal.',
      activeRoute: widget.activeRoute,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WebFilterCard(
            title: 'Búsqueda y filtros',
            trailing: WebPrimaryButton(
              label: 'Nuevo usuario',
              onPressed: () => _openDialog(),
            ),
            children: [
              WebFieldBox(
                width: 320,
                child: TextField(
                  controller: _searchController,
                  decoration: webInputDecoration(
                    'Buscar usuario',
                    hint: 'Nombre, correo o teléfono',
                  ).copyWith(prefixIcon: const Icon(Icons.search_rounded)),
                  onSubmitted: (_) => _load(),
                ),
              ),
              WebFieldBox(
                child: DropdownButtonFormField<int?>(
                  value: _roleFilter,
                  decoration: webInputDecoration('Rol'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Todos los roles'),
                    ),
                    ...mapList(_catalog['roles']).map(
                      (role) => DropdownMenuItem<int?>(
                        value: intValue(role['rol_id']),
                        child: Text(role['rol_nombre']?.toString() ?? '-'),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _roleFilter = value);
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
                      child: Text('Todos los estados'),
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
                label: 'Usuarios cargados',
                value: '${_users.length}',
                icon: Icons.groups_rounded,
              ),
              WebMetric(
                label: 'Usuarios activos',
                value: '$active',
                icon: Icons.verified_user_rounded,
                color: SigmaColors.success,
              ),
              WebMetric(
                label: 'Supervisores',
                value: '$supervisors',
                icon: Icons.supervisor_account_rounded,
                color: SigmaColors.secondary,
              ),
              WebMetric(
                label: 'Visitadores médicos',
                value: '$visitadores',
                icon: Icons.badge_rounded,
                color: SigmaColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 18),
          WebTableContainer(
            title: 'Listado de usuarios',
            child: WebAsyncBody(
              loading: _loading,
              error: _error,
              empty: _users.isEmpty,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Usuario')),
                    DataColumn(label: Text('Correo')),
                    DataColumn(label: Text('Rol')),
                    DataColumn(label: Text('Supervisor')),
                    DataColumn(label: Text('Estado')),
                    DataColumn(label: Text('Acciones')),
                  ],
                  rows: _users.map(_userRow).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _userRow(Map<String, dynamic> user) {
    final active = intValue(user['est_id']) == 1;
    return DataRow(
      cells: [
        DataCell(
          SizedBox(
            width: 205,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: SigmaColors.primary.withOpacity(.10),
                  foregroundColor: SigmaColors.primary,
                  child: Text(
                    _userInitial(user['usu_nombre']?.toString()),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    user['usu_nombre']?.toString() ?? '-',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 210,
            child: Text(
              user['usu_email']?.toString() ?? '-',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(Text(nestedText(user, 'rol.rol_nombre'))),
        DataCell(Text(nestedText(user, 'supervisor.usu_nombre'))),
        DataCell(
          WebStatusChip(
            label: nestedText(user, 'estado.est_nombre'),
            active: active,
          ),
        ),
        DataCell(
          PopupMenuButton<String>(
            tooltip: 'Acciones',
            onSelected: (value) {
              if (value == 'view') {
                _showUserDetails(user);
              } else if (value == 'edit') {
                _openDialog(user);
              } else if (value == 'state') {
                _toggleState(user);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'view',
                child: ListTile(
                  leading: Icon(Icons.visibility_outlined),
                  title: Text('Ver usuario'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Editar usuario'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
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

  Future<void> _showUserDetails(Map<String, dynamic> user) async {
    await showWebDetailDialog(
      context: context,
      title: user['usu_nombre']?.toString() ?? 'Usuario',
      subtitle: 'Ficha de consulta de la cuenta y asignación del personal.',
      icon: Icons.account_circle_outlined,
      editLabel: 'Editar usuario',
      onEdit: () => _openDialog(user),
      sections: [
        WebDetailSection(
          title: 'Datos de la cuenta',
          icon: Icons.person_outline_rounded,
          items: [
            WebDetailItem(
              label: 'Nombre',
              value: user['usu_nombre']?.toString() ?? '-',
              icon: Icons.badge_outlined,
            ),
            WebDetailItem(
              label: 'Correo',
              value: user['usu_email']?.toString() ?? '-',
              icon: Icons.email_outlined,
            ),
            WebDetailItem(
              label: 'Teléfono',
              value: user['usu_telefono']?.toString() ?? 'Sin teléfono',
              icon: Icons.phone_outlined,
            ),
            WebDetailItem(
              label: 'Código interno',
              value: user['usu_id']?.toString() ?? '-',
              icon: Icons.tag_rounded,
            ),
          ],
        ),
        WebDetailSection(
          title: 'Asignación y estado',
          icon: Icons.account_tree_outlined,
          items: [
            WebDetailItem(
              label: 'Rol',
              value: nestedText(user, 'rol.rol_nombre'),
              icon: Icons.manage_accounts_outlined,
            ),
            WebDetailItem(
              label: 'Supervisor',
              value: nestedText(
                user,
                'supervisor.usu_nombre',
                'Sin supervisor',
              ),
              icon: Icons.supervisor_account_outlined,
            ),
            WebDetailItem(
              label: 'Estado',
              value: nestedText(user, 'estado.est_nombre'),
              icon: Icons.toggle_on_outlined,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openDialog([Map<String, dynamic>? user]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _UserFormDialog(provider: _provider, catalog: _catalog, user: user),
    );
    if (saved == true) await _load();
  }

  Future<void> _toggleState(Map<String, dynamic> user) async {
    final current = intValue(user['est_id']) ?? 1;
    final next = current == 1 ? 2 : 1;
    try {
      await _provider.put('/usuarios/${user['usu_id']}', {'est_id': next});
      if (!mounted) return;
      showWebMessage(
        context,
        next == 1 ? 'Usuario activado.' : 'Usuario desactivado.',
      );
      await _load();
    } catch (error) {
      if (mounted) showWebMessage(context, error.toString(), error: true);
    }
  }
}

class _UserFormDialog extends StatefulWidget {
  const _UserFormDialog({
    required this.provider,
    required this.catalog,
    this.user,
  });

  final WebApiProvider provider;
  final Map<String, dynamic> catalog;
  final Map<String, dynamic>? user;

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _password;
  late final TextEditingController _confirmation;
  int? _companyId;
  int? _roleId;
  int? _stateId;
  int? _supervisorId;
  bool _saving = false;

  bool get _editing => widget.user != null;
  bool get _isVisitador => _roleId == 3;

  @override
  void initState() {
    super.initState();
    final user = widget.user ?? <String, dynamic>{};
    _name = TextEditingController(text: user['usu_nombre']?.toString() ?? '');
    _email = TextEditingController(text: user['usu_email']?.toString() ?? '');
    _phone = TextEditingController(
      text: user['usu_telefono']?.toString() ?? '',
    );
    _password = TextEditingController();
    _confirmation = TextEditingController();
    _companyId = intValue(user['emp_id']) ?? _firstId('empresas', 'emp_id');
    _roleId = intValue(user['rol_id']) ?? 3;
    _stateId = intValue(user['est_id']) ?? 1;
    _supervisorId = intValue(user['supervisor_id']);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  int? _firstId(String key, String idKey) {
    final items = mapList(widget.catalog[key]);
    return items.isEmpty ? null : intValue(items.first[idKey]);
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
        title: _editing ? 'Editar usuario' : 'Nuevo usuario',
        subtitle: _editing
            ? 'Actualiza los datos, rol o asignación del usuario.'
            : 'Crea una cuenta y define su rol dentro de SIGPRED.',
        icon: Icons.manage_accounts_outlined,
      ),
      content: SizedBox(
        width: 780,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const WebFormSectionTitle(
                  title: 'Datos de la cuenta',
                  subtitle:
                      'Información básica para identificar y contactar al usuario.',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _name,
                        decoration: webInputDecoration('Nombre completo'),
                        validator: _required,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _email,
                        decoration: webInputDecoration('Correo electrónico'),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty)
                            return 'Campo requerido';
                          if (!value!.contains('@')) return 'Correo no válido';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phone,
                        decoration: webInputDecoration('Teléfono'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _roleId,
                        decoration: webInputDecoration('Rol'),
                        items: mapList(widget.catalog['roles'])
                            .map(
                              (role) => DropdownMenuItem<int>(
                                value: intValue(role['rol_id']),
                                child: Text(
                                  role['rol_nombre']?.toString() ?? '-',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          _roleId = value;
                          if (value != 3) _supervisorId = null;
                        }),
                        validator: (value) =>
                            value == null ? 'Campo requerido' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const WebFormSectionTitle(
                  title: 'Asignación y estado',
                  subtitle:
                      'Define empresa, estado y supervisor cuando corresponda.',
                  icon: Icons.account_tree_outlined,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _companyId,
                        decoration: webInputDecoration('Empresa'),
                        items: mapList(widget.catalog['empresas'])
                            .map(
                              (company) => DropdownMenuItem<int>(
                                value: intValue(company['emp_id']),
                                child: Text(
                                  company['emp_nombre']?.toString() ?? '-',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _companyId = value),
                        validator: (value) =>
                            value == null ? 'Campo requerido' : null,
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
                if (_isVisitador) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    value: _supervisorId,
                    decoration: webInputDecoration('Supervisor asignado'),
                    items: mapList(widget.catalog['supervisores'])
                        .map(
                          (supervisor) => DropdownMenuItem<int>(
                            value: intValue(supervisor['usu_id']),
                            child: Text(
                              supervisor['usu_nombre']?.toString() ?? '-',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _supervisorId = value),
                    validator: (value) =>
                        value == null ? 'Campo requerido' : null,
                  ),
                ],
                const SizedBox(height: 20),
                const WebFormSectionTitle(
                  title: 'Seguridad',
                  subtitle: 'La contraseña debe tener al menos 8 caracteres.',
                  icon: Icons.lock_outline_rounded,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _password,
                        obscureText: true,
                        decoration: webInputDecoration(
                          _editing
                              ? 'Nueva contraseña (opcional)'
                              : 'Contraseña',
                        ),
                        validator: (value) {
                          if (!_editing && (value ?? '').isEmpty)
                            return 'Campo requerido';
                          if ((value ?? '').isNotEmpty && value!.length < 8) {
                            return 'Mínimo 8 caracteres';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _confirmation,
                        obscureText: true,
                        decoration: webInputDecoration('Confirmar contraseña'),
                        validator: (value) {
                          if (_password.text.isNotEmpty &&
                              value != _password.text) {
                            return 'Las contraseñas no coinciden';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
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
          label: _editing ? 'Guardar cambios' : 'Registrar usuario',
          icon: Icons.save_outlined,
          busy: _saving,
          onPressed: _save,
        ),
      ],
    );
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'Campo requerido' : null;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final body = <String, dynamic>{
      'emp_id': _companyId,
      'rol_id': _roleId,
      'est_id': _stateId,
      'supervisor_id': _isVisitador ? _supervisorId : null,
      'usu_nombre': _name.text.trim(),
      'usu_email': _email.text.trim(),
      'usu_telefono': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      if (_password.text.isNotEmpty) 'password': _password.text,
      if (_password.text.isNotEmpty)
        'password_confirmation': _confirmation.text,
    };

    try {
      if (_editing) {
        await widget.provider.put('/usuarios/${widget.user!['usu_id']}', body);
      } else {
        await widget.provider.post('/usuarios', body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) showWebMessage(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

String _userInitial(String? name) {
  final value = (name ?? '').trim();
  return value.isEmpty ? 'U' : value.substring(0, 1).toUpperCase();
}
