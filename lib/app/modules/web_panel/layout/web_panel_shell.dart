import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/user.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../services/auth_service.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/safe_ui.dart';

enum _PanelRole { admin, supervisor }

_PanelRole _panelRoleFromRoute(String route, User? user) {
  if (route.startsWith('/web/supervisor')) return _PanelRole.supervisor;
  if (route.startsWith('/web/admin')) return _PanelRole.admin;

  if (user?.isAdministrador ?? false) return _PanelRole.admin;
  if (user?.isSupervisor ?? false) return _PanelRole.supervisor;

  return _PanelRole.admin;
}

class WebPanelShell extends StatelessWidget {
  const WebPanelShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.activeRoute,
    required this.child,
    this.badge,
  });

  final String title;
  final String subtitle;
  final String activeRoute;
  final Widget child;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    final user = auth.currentUser.value;
    final panelRole = _panelRoleFromRoute(activeRoute, user);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FC),
          drawer: compact
              ? Drawer(
                  width: 272,
                  child: _Sidebar(
                    user: user,
                    activeRoute: activeRoute,
                    panelRole: panelRole,
                    closeDrawerOnNavigate: true,
                  ),
                )
              : null,
          body: Row(
            children: [
              if (!compact)
                _Sidebar(
                  user: user,
                  activeRoute: activeRoute,
                  panelRole: panelRole,
                ),
              Expanded(
                child: Column(
                  children: [
                    Builder(
                      builder: (topBarContext) => _TopBar(
                        user: user,
                        compact: compact,
                        activeRoute: activeRoute,
                        panelRole: panelRole,
                        onOpenMenu: compact
                            ? () => Scaffold.of(topBarContext).openDrawer()
                            : null,
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 16 : 26,
                          compact ? 16 : 22,
                          compact ? 16 : 26,
                          28,
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1440),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _PageHeader(
                                  title: title,
                                  subtitle: subtitle,
                                  badge: badge,
                                  compact: compact,
                                ),
                                const SizedBox(height: 18),
                                if ((user?.isAdministrador ?? false) &&
                                    panelRole == _PanelRole.supervisor) ...[
                                  const _AdminSupervisorModeBanner(),
                                  const SizedBox(height: 14),
                                ],
                                child,
                              ],
                            ),
                          ),
                        ),
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

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.user,
    required this.activeRoute,
    required this.panelRole,
    this.closeDrawerOnNavigate = false,
  });

  final User? user;
  final String activeRoute;
  final _PanelRole panelRole;
  final bool closeDrawerOnNavigate;

  List<_MenuGroup> get _groups {
    if (panelRole == _PanelRole.admin) {
      return const [
        _MenuGroup(
          label: 'PRINCIPAL',
          items: [
            _MenuItem(
              label: 'Inicio',
              icon: Icons.home_outlined,
              route: Routes.webAdminDashboard,
            ),
          ],
        ),
        _MenuGroup(
          label: 'GESTIÓN',
          items: [
            _MenuItem(
              label: 'Usuarios',
              icon: Icons.manage_accounts_outlined,
              route: Routes.webAdminUsuarios,
            ),
            _MenuItem(
              label: 'Clientes',
              icon: Icons.groups_2_outlined,
              route: Routes.webAdminClientes,
            ),
            _MenuItem(
              label: 'Zonas',
              icon: Icons.location_on_outlined,
              route: Routes.webAdminZonas,
            ),
          ],
        ),
        _MenuGroup(
          label: 'OPERACIÓN',
          items: [
            _MenuItem(
              label: 'Rutas',
              icon: Icons.route_outlined,
              route: Routes.webAdminRutas,
            ),
            _MenuItem(
              label: 'Visitas',
              icon: Icons.fact_check_outlined,
              route: Routes.webAdminVisitas,
            ),
            _MenuItem(
              label: 'Actividad diaria',
              icon: Icons.monitor_heart_outlined,
              route: Routes.webAdminOperaciones,
            ),
          ],
        ),
        _MenuGroup(
          label: 'ANÁLISIS',
          items: [
            _MenuItem(
              label: 'Reportes',
              icon: Icons.bar_chart_rounded,
              route: Routes.webAdminReportes,
            ),
            _MenuItem(
              label: 'Predicciones',
              icon: Icons.auto_graph_rounded,
              route: Routes.webAdminPredicciones,
            ),
          ],
        ),
        _MenuGroup(
          label: 'SISTEMA',
          items: [
            _MenuItem(
              label: 'Configuración',
              icon: Icons.settings_outlined,
              route: Routes.webAdminConfiguracion,
            ),
          ],
        ),
      ];
    }

    return const [
      _MenuGroup(
        label: 'PRINCIPAL',
        items: [
          _MenuItem(
            label: 'Inicio',
            icon: Icons.grid_view_rounded,
            route: Routes.webSupervisorDashboard,
          ),
        ],
      ),
      _MenuGroup(
        label: 'OPERACIÓN',
        items: [
          _MenuItem(
            label: 'Zonas',
            icon: Icons.map_outlined,
            route: Routes.webSupervisorZonas,
          ),
          _MenuItem(
            label: 'Clientes',
            icon: Icons.groups_2_outlined,
            route: Routes.webSupervisorClientes,
          ),
          _MenuItem(
            label: 'Rutas',
            icon: Icons.route_outlined,
            route: Routes.webSupervisorRutas,
          ),
          _MenuItem(
            label: 'Visitas',
            icon: Icons.fact_check_outlined,
            route: Routes.webSupervisorVisitas,
          ),
          _MenuItem(
            label: 'Seguimiento',
            icon: Icons.sensors_rounded,
            route: Routes.webSupervisorTracking,
          ),
        ],
      ),
      _MenuGroup(
        label: 'ANÁLISIS',
        items: [
          _MenuItem(
            label: 'Reportes',
            icon: Icons.bar_chart_rounded,
            route: Routes.webSupervisorReportes,
          ),
          _MenuItem(
            label: 'Predicciones',
            icon: Icons.auto_graph_rounded,
            route: Routes.webSupervisorPredicciones,
          ),
        ],
      ),
      _MenuGroup(
        label: 'SISTEMA',
        items: [
          _MenuItem(
            label: 'Configuración',
            icon: Icons.settings_outlined,
            route: Routes.webSupervisorConfiguracion,
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 236,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE8ECF3))),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BrandBlock(),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  children: [
                    for (final group in _groups) ...[
                      _MenuSectionLabel(label: group.label),
                      const SizedBox(height: 7),
                      for (final item in group.items) ...[
                        _MenuTile(
                          item: item,
                          selected: activeRoute == item.route,
                          closeDrawerOnNavigate: closeDrawerOnNavigate,
                        ),
                        const SizedBox(height: 7),
                      ],
                      const SizedBox(height: 7),
                    ],
                  ],
                ),
              ),
              const Divider(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 15,
                      color: Color(0xFF98A2B3),
                    ),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Sesión protegida',
                        style: TextStyle(
                          color: Color(0xFF98A2B3),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'SIGPRED · 2026',
                style: TextStyle(
                  color: Color(0xFF98A2B3),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: Image.asset(
        'assets/images/biofarma_sigma_logo.png',
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
      ),
    );
  }
}

class _MenuSectionLabel extends StatelessWidget {
  const _MenuSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF98A2B3),
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: .8,
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.item,
    required this.selected,
    required this.closeDrawerOnNavigate,
  });

  final _MenuItem item;
  final bool selected;
  final bool closeDrawerOnNavigate;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? SigmaColors.primary.withOpacity(0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: selected
            ? null
            : () {
                if (closeDrawerOnNavigate) {
                  Navigator.of(context).pop();
                  Future.microtask(() => Get.offNamed(item.route));
                } else {
                  Get.offNamed(item.route);
                }
              },
        child: Container(
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? const Border(
                    left: BorderSide(color: SigmaColors.primary, width: 3),
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                color: selected ? SigmaColors.primary : const Color(0xFF475467),
                size: 20,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: selected
                        ? SigmaColors.primary
                        : const Color(0xFF344054),
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.user,
    required this.compact,
    required this.activeRoute,
    required this.panelRole,
    this.onOpenMenu,
  });

  final User? user;
  final bool compact;
  final String activeRoute;
  final _PanelRole panelRole;
  final VoidCallback? onOpenMenu;

  bool get _adminInSupervisorView =>
      (user?.isAdministrador ?? false) && panelRole == _PanelRole.supervisor;

  String get _panelLabel {
    if (_adminInSupervisorView) return 'Vista Supervisor';
    return panelRole == _PanelRole.admin
        ? 'Panel Administrador'
        : 'Panel Supervisor';
  }

  Color get _panelColor =>
      _adminInSupervisorView ? SigmaColors.warning : SigmaColors.primary;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(user?.name ?? 'Usuario');

    return Container(
      height: compact ? 62 : 68,
      padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8ECF3))),
      ),
      child: Row(
        children: [
          if (compact) ...[
            IconButton(
              tooltip: 'Abrir menú',
              onPressed: onOpenMenu,
              icon: const Icon(Icons.menu_rounded),
            ),
            const SizedBox(width: 6),
          ],
          const Text(
            'SIGPRED',
            style: TextStyle(
              color: SigmaColors.primary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: .2,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _panelColor.withOpacity(.09),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: _panelColor.withOpacity(.18)),
              ),
              child: Row(
                children: [
                  Icon(
                    _adminInSupervisorView
                        ? Icons.visibility_outlined
                        : panelRole == _PanelRole.admin
                        ? Icons.admin_panel_settings_outlined
                        : Icons.supervisor_account_outlined,
                    size: 15,
                    color: _panelColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _panelLabel,
                    style: TextStyle(
                      color: _panelColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: 'Cuenta y paneles',
            offset: const Offset(0, 48),
            constraints: const BoxConstraints(minWidth: 280, maxWidth: 320),
            onSelected: (value) => _handleSelection(context, value),
            itemBuilder: (_) {
              final items = <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  enabled: false,
                  height: 74,
                  child: _AccountMenuHeader(user: user),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'account',
                  child: _AccountMenuItem(
                    icon: Icons.person_outline_rounded,
                    title: 'Mi cuenta',
                    subtitle: 'Ver datos de la sesión actual',
                  ),
                ),
              ];

              if (user?.isAdministrador ?? false) {
                items.add(
                  PopupMenuItem<String>(
                    value: 'switch_panel',
                    child: _AccountMenuItem(
                      icon: _adminInSupervisorView
                          ? Icons.admin_panel_settings_outlined
                          : Icons.supervisor_account_outlined,
                      title: _adminInSupervisorView
                          ? 'Volver al panel Administrador'
                          : 'Abrir vista Supervisor',
                      subtitle: _adminInSupervisorView
                          ? 'Regresar a las funciones administrativas'
                          : 'Revisar el sistema como panel de supervisión',
                    ),
                  ),
                );
              }

              items.addAll([
                const PopupMenuItem<String>(
                  value: 'settings',
                  child: _AccountMenuItem(
                    icon: Icons.settings_outlined,
                    title: 'Configuración',
                    subtitle: 'Abrir opciones del panel',
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'change_account',
                  child: _AccountMenuItem(
                    icon: Icons.switch_account_outlined,
                    title: 'Cambiar cuenta',
                    subtitle: 'Salir y entrar con otro usuario',
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: _AccountMenuItem(
                    icon: Icons.logout_rounded,
                    title: 'Cerrar sesión',
                    subtitle: 'Finalizar la sesión actual',
                    danger: true,
                  ),
                ),
              ]);

              return items;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: SigmaColors.primary,
                    foregroundColor: Colors.white,
                    radius: compact ? 17 : 19,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 190),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'Usuario',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5,
                            ),
                          ),
                          Text(
                            user?.email ?? user?.roleLabel ?? 'Cuenta activa',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF667085),
                              fontWeight: FontWeight.w600,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: Color(0xFF667085),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSelection(BuildContext context, String value) {
    switch (value) {
      case 'account':
        _showAccountDialog(context, user);
        break;
      case 'switch_panel':
        if (_adminInSupervisorView) {
          Get.offNamed(Routes.webAdminDashboard);
        } else {
          Get.offNamed(Routes.webSupervisorDashboard);
        }
        break;
      case 'settings':
        Get.toNamed(
          panelRole == _PanelRole.admin
              ? Routes.webAdminConfiguracion
              : Routes.webSupervisorConfiguracion,
        );
        break;
      case 'change_account':
        _endSession(changeAccount: true);
        break;
      case 'logout':
        _endSession();
        break;
    }
  }
}

class _AccountMenuHeader extends StatelessWidget {
  const _AccountMenuHeader({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: SigmaColors.primary.withOpacity(.10),
          foregroundColor: SigmaColors.primary,
          child: Text(
            _initials(user?.name ?? 'Usuario'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.name ?? 'Usuario',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: SigmaColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user?.email ?? user?.roleLabel ?? 'Cuenta activa',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: SigmaColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountMenuItem extends StatelessWidget {
  const _AccountMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? SigmaColors.danger : SigmaColors.ink;

    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: SigmaColors.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminSupervisorModeBanner extends StatelessWidget {
  const _AdminSupervisorModeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: SigmaColors.warning.withOpacity(.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SigmaColors.warning.withOpacity(.22)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.visibility_outlined,
            color: SigmaColors.warning,
            size: 20,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Vista Supervisor: continúas autenticado como Administrador. Esta vista sirve para revisar el flujo de supervisión sin cambiar de cuenta.',
              style: TextStyle(
                color: SigmaColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          TextButton.icon(
            onPressed: () => Get.offNamed(Routes.webAdminDashboard),
            icon: const Icon(Icons.arrow_back_rounded, size: 17),
            label: const Text('Volver a Administrador'),
            style: TextButton.styleFrom(
              foregroundColor: SigmaColors.primary,
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showAccountDialog(BuildContext context, User? user) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Mi cuenta'),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AccountDetailRow(
              icon: Icons.person_outline_rounded,
              label: 'Nombre',
              value: user?.name ?? 'Sin nombre',
            ),
            _AccountDetailRow(
              icon: Icons.email_outlined,
              label: 'Correo',
              value: user?.email ?? 'Sin correo',
            ),
            _AccountDetailRow(
              icon: Icons.badge_outlined,
              label: 'Rol',
              value: user?.roleLabel ?? 'Sin rol',
            ),
            _AccountDetailRow(
              icon: Icons.business_outlined,
              label: 'Empresa',
              value: user?.empresaNombre ?? 'Sin empresa',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

class _AccountDetailRow extends StatelessWidget {
  const _AccountDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: SigmaColors.primary),
          const SizedBox(width: 11),
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: const TextStyle(
                color: SigmaColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: SigmaColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    required this.compact,
    this.badge,
  });

  final String title;
  final String subtitle;
  final String? badge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                color: const Color(0xFF111827),
                fontSize: compact ? 22 : 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: SigmaColors.primary.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: SigmaColors.primary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .4,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _endSession({bool changeAccount = false}) async {
  if (!Get.isRegistered<AuthService>()) return;

  final auth = Get.find<AuthService>();

  try {
    if (Get.isRegistered<AuthProvider>() && auth.token.value.isNotEmpty) {
      await Get.find<AuthProvider>().logout(token: auth.token.value);
    }
  } catch (_) {}

  await auth.clearSession();

  SafeUi.snackbar(
    changeAccount ? 'Cambiar cuenta' : 'Sesión',
    changeAccount
        ? 'Selecciona la cuenta con la que deseas ingresar.'
        : 'Sesión cerrada correctamente.',
  );

  Get.offAllNamed(Routes.login);
}

Future<void> _logout() => _endSession();

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'U';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

class _MenuGroup {
  const _MenuGroup({required this.label, required this.items});

  final String label;
  final List<_MenuItem> items;
}

class _MenuItem {
  const _MenuItem({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}
