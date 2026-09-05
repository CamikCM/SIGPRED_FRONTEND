import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../routes/app_routes.dart';
import '../../../services/auth_service.dart';
import '../../../utils/app_theme.dart';

class AdminMobileBlockedView extends StatelessWidget {
  const AdminMobileBlockedView({super.key});

  Future<void> _logout() async {
    await Get.find<AuthService>().clearSession();
    Get.offAllNamed(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SigmaColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: SigmaColors.primary.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: SigmaColors.primary,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Acceso móvil no disponible',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'El perfil Administrador debe ingresar desde el módulo web administrativo de SIGPRED.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black54,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Volver al login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
