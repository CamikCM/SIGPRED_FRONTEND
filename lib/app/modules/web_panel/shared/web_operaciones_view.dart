import 'package:flutter/material.dart';

import '../../../routes/app_routes.dart';
import 'web_operational_dashboard.dart';

class WebOperacionesView extends StatelessWidget {
  const WebOperacionesView({
    super.key,
    this.activeRoute = Routes.webAdminOperaciones,
  });

  final String activeRoute;

  @override
  Widget build(BuildContext context) {
    return WebOperationalDashboard(
      title: 'Actividad diaria',
      subtitle:
          'Revisa el avance diario de jornadas, rutas, visitas y pedidos.',
      activeRoute: activeRoute,
      isSupervisor: false,
    );
  }
}
