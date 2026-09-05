import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../services/auth_service.dart';
import '../../../utils/app_theme.dart';
import '../tabs/logout_tab_view.dart';
import 'supervisor_mobile_predictions_view.dart';
import 'supervisor_mobile_reports_view.dart';
import 'supervisor_mobile_ui.dart';
import 'supervisor_mobile_visits_view.dart';

class SupervisorMobileMoreView extends StatelessWidget {
  const SupervisorMobileMoreView({super.key});

  Future<void> _openPage(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (routeContext) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Material(
            color: Theme.of(routeContext).scaffoldBackgroundColor,
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    final user = auth.currentUser.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 92),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: SigmaColors.primary.withOpacity(.10),
              foregroundColor: SigmaColors.primary,
              child: Text(
                _initials(user?.name ?? 'Supervisor'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.name ?? 'Supervisor',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Supervisor · SIGPRED',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const SupervisorSectionHeader(
          title: 'Consultas',
          subtitle:
              'El mapa concentra seguimiento y puntos asignados. '
              'Aquí quedan solo las consultas secundarias.',
        ),
        const SizedBox(height: 8),
        SupervisorActionTile(
          icon: Icons.fact_check_outlined,
          title: 'Visitas',
          subtitle: 'Consulta realizadas con pedido y sin pedido.',
          color: SigmaColors.success,
          onTap: () => _openPage(
            context,
            title: 'Visitas',
            child: const SupervisorMobileVisitsView(),
          ),
        ),
        SupervisorActionTile(
          icon: Icons.bar_chart_rounded,
          title: 'Reportes',
          subtitle: 'Indicadores y resultados del equipo.',
          color: SigmaColors.warning,
          onTap: () => _openPage(
            context,
            title: 'Reportes',
            child: const SupervisorMobileReportsView(),
          ),
        ),
        SupervisorActionTile(
          icon: Icons.auto_graph_rounded,
          title: 'Predicciones',
          subtitle: 'Ventas esperadas por visitador, cliente, zona y producto.',
          color: const Color(0xFF7C3AED),
          onTap: () => _openPage(
            context,
            title: 'Predicciones',
            child: const SupervisorMobilePredictionsView(),
          ),
        ),
        const SizedBox(height: 12),
        const SupervisorSectionHeader(title: 'Aplicación'),
        const SizedBox(height: 8),
        SupervisorActionTile(
          icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          title: isDark ? 'Modo claro' : 'Modo oscuro',
          subtitle: 'Cambia la apariencia de este dispositivo.',
          color: SigmaColors.muted,
          onTap: () =>
              Get.changeThemeMode(isDark ? ThemeMode.light : ThemeMode.dark),
        ),
        SupervisorActionTile(
          icon: Icons.logout_rounded,
          title: 'Cerrar sesión',
          subtitle: 'Finaliza tu sesión en este dispositivo.',
          color: SigmaColors.danger,
          onTap: () => _openPage(
            context,
            title: 'Cerrar sesión',
            child: const LogoutTabView(),
          ),
        ),
      ],
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((item) => item.isNotEmpty)
      .toList();

  if (parts.isEmpty) return 'S';
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }

  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}
