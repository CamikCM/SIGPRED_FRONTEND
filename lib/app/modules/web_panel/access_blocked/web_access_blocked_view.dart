import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../routes/app_routes.dart';
import '../../../services/auth_service.dart';
import '../../../utils/app_theme.dart';

class WebAccessBlockedView extends StatelessWidget {
  const WebAccessBlockedView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    final user = auth.currentUser.value;

    return Scaffold(
      backgroundColor: SigmaColors.surface,
      body: Center(
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: SigmaColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.phonelink_lock_rounded,
                  color: SigmaColors.primary,
                  size: 44,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Acceso web no disponible',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'El perfil ${user?.roleLabel ?? 'actual'} debe utilizar la aplicación móvil para sus operaciones de campo.',
                style: const TextStyle(
                  color: SigmaColors.muted,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  await auth.clearSession();
                  Get.offAllNamed(Routes.login);
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Volver al login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
