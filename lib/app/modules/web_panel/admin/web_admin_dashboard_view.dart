import 'package:flutter/material.dart';

import '../../../routes/app_routes.dart';
import '../shared/web_operational_dashboard.dart';

class WebAdminDashboardView extends StatelessWidget {
  const WebAdminDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return const WebOperationalDashboard(
      title: 'Inicio',
      subtitle:
          'Panorama gerencial de ventas, efectividad, cobertura y alertas para decidir dónde actuar.',
      activeRoute: Routes.webAdminDashboard,
      isSupervisor: false,
      showQuickActions: true,
    );
  }
}
