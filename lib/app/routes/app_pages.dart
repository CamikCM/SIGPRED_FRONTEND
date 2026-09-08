import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../app/modules/auth/logout/logout_binding.dart';
import '../../app/modules/home/tabs/logout_tab_view.dart';
import '../modules/auth/login/login_binding.dart';
import '../modules/auth/login/login_view.dart';
import '../modules/home/admin/admin_mobile_blocked_view.dart';
import '../modules/home/home_binding.dart';
import '../modules/home/role/role_home_view.dart';
import '../modules/home/supervisor/supervisor_home_view.dart';
import '../modules/home/visitador/visitador_home_view.dart';
import '../modules/web_panel/access_blocked/web_access_blocked_view.dart';
import '../modules/web_panel/admin/web_admin_dashboard_view.dart';
import '../modules/web_panel/shared/web_clientes_view.dart';
import '../modules/web_panel/shared/web_configuracion_view.dart';
import '../modules/web_panel/shared/web_reportes_view.dart';
import '../modules/web_panel/shared/web_operaciones_view.dart';
import '../modules/web_panel/shared/web_predicciones_view.dart';
import '../modules/web_panel/shared/web_rutas_view.dart';
import '../modules/web_panel/shared/web_tracking_view.dart';
import '../modules/web_panel/shared/web_zonas_view.dart';
import '../modules/web_panel/shared/web_usuarios_view.dart';
import '../modules/web_panel/shared/web_visitas_view.dart';
import '../modules/web_panel/supervisor/web_supervisor_dashboard_view.dart';
import '../services/auth_service.dart';
import 'app_routes.dart';
import 'auth_middleware.dart';

class AppPages {
  static final pages = <GetPage>[
    // ------------------------------------------------------------
    // RUTA PÚBLICA
    // ------------------------------------------------------------
    GetPage(
      name: Routes.login,
      page: () => const LoginView(),
      binding: LoginBinding(),
    ),

    // ------------------------------------------------------------
    // RUTAS MÓVILES PROTEGIDAS
    // ------------------------------------------------------------
    GetPage(
      name: Routes.roleHome,
      page: () => const RoleHomeView(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Routes.home,
      page: () => const VisitadorHomeView(),
      binding: HomeBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Routes.supervisorHome,
      page: () => const SupervisorHomeView(),
      binding: HomeBinding(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Routes.adminBlocked,
      page: () => const AdminMobileBlockedView(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: '/logout',
      page: () => const LogoutTabView(),
      binding: LogoutBinding(),
      middlewares: [AuthMiddleware()],
    ),

    // ------------------------------------------------------------
    // PANEL WEB
    // ------------------------------------------------------------

    // Dashboard Administrador.
    GetPage(
      name: Routes.webAdminDashboard,
      page: () => _adminOnly(const WebAdminDashboardView()),
      middlewares: [AuthMiddleware()],
    ),

    // Dashboard Supervisor.
    GetPage(
      name: Routes.webSupervisorDashboard,
      page: () => _supervisorOnly(const WebSupervisorDashboardView()),
      middlewares: [AuthMiddleware()],
    ),

    // Acceso bloqueado.
    GetPage(
      name: Routes.webAccessBlocked,
      page: () => const WebAccessBlockedView(),
      middlewares: [AuthMiddleware()],
    ),

    // ------------------------------------------------------------
    // PANEL WEB ADMINISTRADOR
    // ------------------------------------------------------------
    GetPage(
      name: Routes.webAdminUsuarios,
      page: () => _adminOnly(
        const WebUsuariosView(activeRoute: Routes.webAdminUsuarios),
      ),
      middlewares: [AuthMiddleware()],
    ),

    GetPage(
      name: Routes.webAdminClientes,
      page: () => _adminOnly(
        const WebClientesView(activeRoute: Routes.webAdminClientes),
      ),
      middlewares: [AuthMiddleware()],
    ),

    GetPage(
      name: Routes.webAdminZonas,
      page: () =>
          _adminOnly(const WebZonasView(activeRoute: Routes.webAdminZonas)),
      middlewares: [AuthMiddleware()],
    ),

    GetPage(
      name: Routes.webAdminRutas,
      page: () =>
          _adminOnly(const WebRutasView(activeRoute: Routes.webAdminRutas)),
      middlewares: [AuthMiddleware()],
    ),

    GetPage(
      name: Routes.webAdminVisitas,
      page: () => _adminOnly(
        const WebVisitasView(
          activeRoute: Routes.webAdminVisitas,
          title: 'Visitas y resultados',
          subtitle:
              'Consulta la actividad registrada por el personal de campo y sus resultados.',
        ),
      ),
      middlewares: [AuthMiddleware()],
    ),

    GetPage(
      name: Routes.webAdminOperaciones,
      page: () => _adminOnly(
        const WebOperacionesView(activeRoute: Routes.webAdminOperaciones),
      ),
      middlewares: [AuthMiddleware()],
    ),

    GetPage(
      name: Routes.webAdminReportes,
      page: () => _adminOnly(
        const WebReportesView(activeRoute: Routes.webAdminReportes),
      ),
      middlewares: [AuthMiddleware()],
    ),

    GetPage(
      name: Routes.webAdminPredicciones,
      page: () => _adminOnly(
        const WebPrediccionesView(activeRoute: Routes.webAdminPredicciones),
      ),
      middlewares: [AuthMiddleware()],
    ),

    GetPage(
      name: Routes.webAdminConfiguracion,
      page: () => _adminOnly(
        const WebConfiguracionView(activeRoute: Routes.webAdminConfiguracion),
      ),
      middlewares: [AuthMiddleware()],
    ),

    // ------------------------------------------------------------
    // PANEL WEB SUPERVISOR
    // ------------------------------------------------------------
    GetPage(
      name: Routes.webSupervisorZonas,
      page: () => _supervisorOnly(
        const WebZonasView(
          activeRoute: Routes.webSupervisorZonas,
          title: 'Zonas supervisadas',
          subtitle: 'Consulta las zonas asignadas y su cobertura operativa.',
        ),
      ),
      middlewares: [AuthMiddleware()],
    ),

    GetPage(
      name: Routes.webSupervisorClientes,
      page: () => _supervisorOnly(
        const WebClientesView(
          activeRoute: Routes.webSupervisorClientes,
          title: 'Clientes por zona',
          subtitle: 'Consulta clientes y puntos de visita bajo supervisión.',
        ),
      ),
      middlewares: [AuthMiddleware()],
    ),

    GetPage(
      name: Routes.webSupervisorRutas,
      page: () => _supervisorOnly(
        const WebRutasView(
          activeRoute: Routes.webSupervisorRutas,
          title: 'Rutas del día',
          subtitle: 'Seguimiento de rutas asignadas al equipo de campo.',
        ),
      ),
      middlewares: [AuthMiddleware()],
    ),

    GetPage(
      name: Routes.webSupervisorVisitas,
      page: () => _supervisorOnly(
        const WebVisitasView(activeRoute: Routes.webSupervisorVisitas),
      ),
      middlewares: [AuthMiddleware()],
    ),

    GetPage(
      name: Routes.webSupervisorTracking,
      page: () => _supervisorOnly(
        const WebTrackingView(activeRoute: Routes.webSupervisorTracking),
      ),
      middlewares: [AuthMiddleware()],
    ),

    GetPage(
      name: Routes.webSupervisorReportes,
      page: () => _supervisorOnly(
        const WebReportesView(
          activeRoute: Routes.webSupervisorReportes,
          title: 'Reportes de supervisión',
          subtitle:
              'Indicadores de cumplimiento, visitas y efectividad por zona.',
        ),
      ),
      middlewares: [AuthMiddleware()],
    ),

    GetPage(
      name: Routes.webSupervisorPredicciones,
      page: () => _supervisorOnly(
        const WebPrediccionesView(
          activeRoute: Routes.webSupervisorPredicciones,
          title: 'Predicciones del equipo',
          subtitle:
              'Consulta pronósticos de visitadores, clientes y zonas bajo supervisión.',
        ),
      ),
      middlewares: [AuthMiddleware()],
    ),

    GetPage(
      name: Routes.webSupervisorConfiguracion,
      page: () => _supervisorOnly(
        const WebConfiguracionView(
          activeRoute: Routes.webSupervisorConfiguracion,
          title: 'Configuración del supervisor',
          subtitle:
              'Preferencias visuales y parámetros de consulta del panel supervisor.',
        ),
      ),
      middlewares: [AuthMiddleware()],
    ),
  ];
}

Widget _adminOnly(Widget child) {
  if (!Get.isRegistered<AuthService>()) {
    return const WebAccessBlockedView();
  }

  final user = Get.find<AuthService>().currentUser.value;

  return (user?.isAdministrador ?? false)
      ? child
      : const WebAccessBlockedView();
}

Widget _supervisorOnly(Widget child) {
  if (!Get.isRegistered<AuthService>()) {
    return const WebAccessBlockedView();
  }

  final user = Get.find<AuthService>().currentUser.value;

  // El Administrador puede abrir la vista web del Supervisor para revisión
  // operativa. No cambia su rol, no suplanta a otro usuario y conserva los
  // permisos del token administrativo.
  final canViewSupervisorPanel =
      (user?.isSupervisor ?? false) || (user?.isAdministrador ?? false);

  return canViewSupervisorPanel ? child : const WebAccessBlockedView();
}
