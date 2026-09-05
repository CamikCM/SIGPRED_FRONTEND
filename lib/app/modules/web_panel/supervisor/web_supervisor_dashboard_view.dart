import 'package:flutter/material.dart';

import '../../../routes/app_routes.dart';
import '../shared/web_operational_dashboard.dart';

class WebSupervisorDashboardView extends StatelessWidget {
  const WebSupervisorDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return const WebOperationalDashboard(
      title: 'Dashboard supervisor',
      subtitle:
          'Seguimiento diario del equipo de campo, cumplimiento de rutas y efectividad de visitas.',
      activeRoute: Routes.webSupervisorDashboard,
      isSupervisor: true,
    );
  }
}
