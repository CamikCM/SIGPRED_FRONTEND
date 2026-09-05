import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../routes/app_routes.dart';
import '../../../services/auth_service.dart';
import '../../../utils/app_theme.dart';

class RoleHomeView extends StatelessWidget {
  const RoleHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    final user = auth.currentUser.value;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (user == null) {
        Get.offAllNamed(Routes.login);
        return;
      }

      if (kIsWeb) {
        if (user.isAdministrador) {
          Get.offAllNamed(Routes.webAdminDashboard);
          return;
        }

        if (user.isSupervisor) {
          Get.offAllNamed(Routes.webSupervisorDashboard);
          return;
        }

        if (user.isVisitador) {
          Get.offAllNamed(Routes.webAccessBlocked);
          return;
        }
      } else {
        if (user.isVisitador) {
          Get.offAllNamed(Routes.home);
          return;
        }

        if (user.isSupervisor) {
          Get.offAllNamed(Routes.supervisorHome);
          return;
        }

        if (user.isAdministrador) {
          Get.offAllNamed(Routes.adminBlocked);
          return;
        }
      }

      Get.offAllNamed(Routes.login);
    });

    return const Scaffold(
      backgroundColor: SigmaColors.surface,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: SigmaColors.primary),
              SizedBox(height: 18),
              Text(
                'Preparando interfaz según perfil...',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
