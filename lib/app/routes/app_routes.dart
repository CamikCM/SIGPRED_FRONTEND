abstract class Routes {
  static const login = '/login';

  /// Selector general después del login. Decide la interfaz según plataforma y rol.
  static const roleHome = '/role-home';

  /// App móvil - Visitador Médico.
  static const home = '/home';

  /// App móvil - Supervisor.
  static const supervisorHome = '/supervisor-home';

  /// App móvil - Administrador bloqueado.
  static const adminBlocked = '/admin-blocked';

  /// Web - accesos principales por rol.
  static const webAdminDashboard = '/web/admin/dashboard';
  static const webSupervisorDashboard = '/web/supervisor/dashboard';
  static const webAccessBlocked = '/web/access-blocked';

  /// Web Administrador - módulos propios.
  static const webAdminUsuarios = '/web/admin/usuarios';
  static const webAdminClientes = '/web/admin/clientes';
  static const webAdminZonas = '/web/admin/zonas';
  static const webAdminRutas = '/web/admin/rutas';
  static const webAdminVisitas = '/web/admin/visitas';
  static const webAdminOperaciones = '/web/admin/operaciones';
  static const webAdminReportes = '/web/admin/reportes';
  static const webAdminPredicciones = '/web/admin/predicciones';
  static const webAdminConfiguracion = '/web/admin/configuracion';

  /// Web Supervisor - módulos propios.
  static const webSupervisorZonas = '/web/supervisor/zonas';
  static const webSupervisorClientes = '/web/supervisor/clientes';
  static const webSupervisorRutas = '/web/supervisor/rutas';
  static const webSupervisorVisitas = '/web/supervisor/visitas';
  static const webSupervisorTracking = '/web/supervisor/tracking';
  static const webSupervisorReportes = '/web/supervisor/reportes';
  static const webSupervisorPredicciones = '/web/supervisor/predicciones';
  static const webSupervisorConfiguracion = '/web/supervisor/configuracion';

  /// Alias antiguos conservados para no romper navegación previa.
  static const webUsuarios = webAdminUsuarios;
  static const webClientes = webAdminClientes;
  static const webZonas = webAdminZonas;
  static const webRutas = webAdminRutas;
  static const webVisitas = webSupervisorVisitas;
  static const webTracking = webSupervisorTracking;
  static const webOperaciones = webAdminOperaciones;
  static const webReportes = webAdminReportes;
  static const webPredicciones = webAdminPredicciones;
  static const webConfiguracion = webAdminConfiguracion;
}
