import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../services/auth_service.dart';
import '../../../utils/app_theme.dart';
import '../../auth/logout/logout_controller.dart';
import 'visitador_operativo_controller.dart';

class VisitadorMasView extends StatelessWidget {
  const VisitadorMasView({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Deseas cerrar tu sesión en este dispositivo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (Get.isRegistered<LogoutController>()) {
      await Get.find<LogoutController>().doLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    final controller = Get.isRegistered<VisitadorOperativoController>()
        ? Get.find<VisitadorOperativoController>()
        : Get.put(VisitadorOperativoController());

    return Obx(() {
      final name = auth.currentUser.value?.name ?? 'Visitador médico';
      final status = !controller.jornadaActiva
          ? 'Sin jornada activa'
          : controller.jornadaPausada.value
          ? 'Jornada pausada'
          : 'Jornada en curso';

      return ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
        children: [
          _ProfileCard(name: name, status: status),
          const SizedBox(height: 12),
          _MenuItem(
            icon: Icons.cloud_done_outlined,
            title: 'Estado de mis datos',
            subtitle: controller.pendientesOffline == 0
                ? 'Todo está actualizado.'
                : '${controller.pendientesOffline} registro(s) pendiente(s) de envío.',
            trailing: controller.pendientesOffline > 0
                ? TextButton(
                    onPressed: controller.sincronizarPendientesOffline,
                    child: const Text('Enviar'),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          const _MenuItem(
            icon: Icons.location_on_outlined,
            title: 'Cómo usamos tu ubicación',
            subtitle:
                'Solo durante la jornada para ayudarte con la ruta y validar la llegada.',
          ),
          const SizedBox(height: 8),
          const _MenuItem(
            icon: Icons.help_outline_rounded,
            title: '¿Necesitas ayuda?',
            subtitle:
                'Si falta una visita o algo no funciona, comunícate con tu supervisor.',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Cerrar sesión'),
            style: OutlinedButton.styleFrom(
              foregroundColor: SigmaColors.danger,
            ),
          ),
        ],
      );
    });
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.name, required this.status});

  final String name;
  final String status;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? 'V'
        : name.trim().substring(0, 1).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: SigmaColors.primary.withOpacity(0.10),
            child: Text(
              initial,
              style: const TextStyle(
                color: SigmaColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: SigmaColors.primary.withOpacity(0.09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: SigmaColors.primary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
