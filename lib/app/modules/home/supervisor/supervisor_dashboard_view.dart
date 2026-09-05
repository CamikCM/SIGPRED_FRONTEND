import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../utils/app_theme.dart';
import 'supervisor_dashboard_controller.dart';
import 'supervisor_mobile_ui.dart';

class SupervisorDashboardView extends GetView<SupervisorDashboardController> {
  const SupervisorDashboardView({super.key, required this.onOpenMap});

  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value && controller.resumen.value == null) {
        return const Center(child: CircularProgressIndicator());
      }

      final effectiveness = controller.efectividad.clamp(0, 100).toDouble();
      final effectivenessColor = effectiveness >= 70
          ? SigmaColors.success
          : effectiveness >= 50
          ? SigmaColors.warning
          : SigmaColors.danger;

      return RefreshIndicator(
        onRefresh: () => controller.load(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 92),
          children: [
            Text(
              'Supervisión del día',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(
              'Revisa lo importante y abre el mapa cuando necesites intervenir.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            SupervisorDateNavigator(
              date: controller.selectedDate.value,
              onPrevious: controller.previousDay,
              onNext: controller.canGoNext ? controller.nextDay : null,
              onPick: () => controller.selectDate(context),
              label: 'Día supervisado',
              compact: true,
            ),
            if (controller.isUsingCache.value) ...[
              const SizedBox(height: 10),
              _OfflineBanner(message: controller.errorMessage.value),
            ],
            const SizedBox(height: 12),
            SigmaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _MainMetric(
                          label: 'Efectividad',
                          value: '${effectiveness.toStringAsFixed(1)}%',
                          color: effectivenessColor,
                          caption: 'con pedido ÷ realizadas',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MainMetric(
                          label: 'Pendientes',
                          value: '${controller.puntosPendientes}',
                          color: SigmaColors.warning,
                          caption:
                              '${controller.totalPuntosPlanificados} planificados',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  const Divider(height: 1),
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniMetric(
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Con pedido',
                          value: '${controller.visitasEfectivas}',
                          color: SigmaColors.success,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MiniMetric(
                          icon: Icons.remove_shopping_cart_outlined,
                          label: 'Sin pedido',
                          value: '${controller.visitasNoEfectivas}',
                          color: SigmaColors.danger,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MiniMetric(
                          icon: Icons.badge_outlined,
                          label: 'Jornadas',
                          value: '${controller.jornadasIniciadas}',
                          color: SigmaColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _AttentionCard(controller: controller),
            const SizedBox(height: 12),
            Material(
              color: SigmaColors.primary,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: onOpenMap,
                borderRadius: BorderRadius.circular(18),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.map_rounded, color: Colors.white, size: 27),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Abrir mapa del equipo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Ubicación, ruta del día y estado de cada visita.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.controller});

  final SupervisorDashboardController controller;

  @override
  Widget build(BuildContext context) {
    final rows = <_AttentionItem>[];

    if (controller.puntosPendientes > 0) {
      rows.add(
        _AttentionItem(
          color: SigmaColors.warning,
          icon: Icons.route_outlined,
          title: '${controller.puntosPendientes} puntos pendientes',
          message: 'Revisa en el mapa qué rutas necesitan seguimiento.',
        ),
      );
    }

    if (controller.visitasNoEfectivas > 0) {
      rows.add(
        _AttentionItem(
          color: SigmaColors.danger,
          icon: Icons.remove_shopping_cart_outlined,
          title: '${controller.visitasNoEfectivas} visitas sin pedido',
          message: 'Conviene revisar visitador, cliente, zona y producto.',
        ),
      );
    }

    if (rows.isEmpty) {
      rows.add(
        const _AttentionItem(
          color: SigmaColors.success,
          icon: Icons.check_circle_outline_rounded,
          title: 'Sin alertas prioritarias',
          message:
              'La operación no presenta contingencias con los datos actuales.',
        ),
      );
    }

    return SigmaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Atención',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 9),
          ...rows
              .take(2)
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.icon, color: item.color, size: 18),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              item.message,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(height: 1.25),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _MainMetric extends StatelessWidget {
  const _MainMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.caption,
  });

  final String label;
  final String value;
  final Color color;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 27,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _AttentionItem {
  const _AttentionItem({
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String message;
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: SigmaColors.warning.withOpacity(.08),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: SigmaColors.warning,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Datos guardados. $message',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
