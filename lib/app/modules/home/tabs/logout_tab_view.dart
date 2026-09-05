import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../utils/safe_ui.dart';
import '../../auth/logout/logout_controller.dart';

class LogoutTabView extends GetView<LogoutController> {
  const LogoutTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Obx(() {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.logout, size: 56),
              const SizedBox(height: 12),
              const Text(
                'Vas a cerrar sesión en este dispositivo.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: controller.isLoading.value
                    ? null
                    : () => controller.doLogout(),
                icon: controller.isLoading.value
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout),
                label: Text(
                  controller.isLoading.value ? 'Cerrando...' : 'Cerrar sesión',
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => SafeUi.snackbar('Info', 'Acción cancelada'),
                child: const Text('Cancelar'),
              ),
            ],
          );
        }),
      ),
    );
  }
}
