import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../data/models/pedido_item_draft.dart';
import '../../../utils/app_theme.dart';
import 'visitador_operativo_controller.dart';
import 'visitador_signature_pad.dart';

class VisitadorOperativoView extends StatefulWidget {
  const VisitadorOperativoView({super.key, this.onOpenRoute});

  final VoidCallback? onOpenRoute;

  @override
  State<VisitadorOperativoView> createState() => _VisitadorOperativoViewState();
}

class _VisitadorOperativoViewState extends State<VisitadorOperativoView> {
  late final VisitadorOperativoController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<VisitadorOperativoController>()
        ? Get.find<VisitadorOperativoController>()
        : Get.put(VisitadorOperativoController());
  }

  Map<String, dynamic>? _activeDetail() {
    final draft = controller.visitaActiva.value;
    if (draft != null) {
      return Map<String, dynamic>.from(draft.detalleRuta);
    }

    for (final item in controller.detallesRutaOrdenados) {
      if (controller.esDetalleVisitaActiva(item)) return item;
    }
    return null;
  }

  Future<void> _finishDay() async {
    if (!controller.jornadaActiva) return;

    if (controller.tieneVisitaActiva) {
      final action = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Tienes una visita pendiente'),
          content: Text(
            'La visita de ${controller.visitaActivaClienteNombre} todavía no fue guardada.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('continue'),
              child: const Text('Continuar'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(dialogContext).pop('discard'),
              child: const Text('Cancelar visita'),
            ),
          ],
        ),
      );

      if (action == 'continue') {
        final detail = _activeDetail();
        if (detail != null && mounted) {
          await _showVisitDialog(context, controller, detail);
        }
        return;
      }
      if (action == 'discard') {
        await controller.descartarVisitaActiva();
      } else {
        return;
      }
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finalizar jornada'),
        content: Text(
          controller.visitasPendientes > 0
              ? 'Todavía tienes ${controller.visitasPendientes} visita(s) pendiente(s). ¿Finalizar de todas maneras?'
              : 'Terminaste las visitas de hoy. ¿Deseas finalizar la jornada?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Seguir trabajando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.cerrarJornada();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value &&
          controller.rutaHoy.value == null &&
          controller.jornadaHoy.value == null) {
        return const Center(child: CircularProgressIndicator());
      }

      final total = controller.detallesRuta.length;
      final done = controller.visitasRealizadas.clamp(0, total);
      final pending = (total - done).clamp(0, total);
      final activeDetail = _activeDetail();
      final suggested = controller.siguienteVisitaSugerida;
      final paused = controller.jornadaPausada.value;

      return RefreshIndicator(
        onRefresh: controller.refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
          children: [
            _SimpleDayHeader(
              done: done,
              pending: pending,
              total: total,
              active: controller.jornadaActiva,
              paused: paused,
            ),
            const SizedBox(height: 12),

            if (!controller.jornadaActiva)
              _PrimaryActionCard(
                icon: Icons.play_circle_fill_rounded,
                title: controller.jornadaCerrada
                    ? '¿Volvemos a trabajar?'
                    : 'Empieza tu jornada',
                description: controller.tieneRuta
                    ? 'Activa tu ubicación y abre el mapa con todas las visitas del día.'
                    : 'Tu supervisor todavía no ha preparado una ruta para hoy.',
                buttonText: controller.jornadaCerrada
                    ? 'Iniciar nuevamente'
                    : 'Iniciar jornada',
                buttonIcon: Icons.play_arrow_rounded,
                enabled: controller.tieneRuta && !controller.isSubmitting.value,
                onPressed: () async {
                  await controller.iniciarJornada();
                  if (controller.jornadaActiva) {
                    widget.onOpenRoute?.call();
                  }
                },
              )
            else if (paused)
              _PrimaryActionCard(
                icon: Icons.pause_circle_filled_rounded,
                title: 'Jornada pausada',
                description:
                    'Tu ubicación está detenida temporalmente. Reanuda cuando vuelvas a trabajar.',
                buttonText: 'Reanudar jornada',
                buttonIcon: Icons.play_arrow_rounded,
                enabled: !controller.isSubmitting.value,
                onPressed: () async {
                  await controller.reanudarJornada();
                  if (!controller.jornadaPausada.value) {
                    widget.onOpenRoute?.call();
                  }
                },
                secondaryText: 'Finalizar jornada',
                onSecondary: _finishDay,
              )
            else if (activeDetail != null)
              _ActiveVisitCard(
                controller: controller,
                detail: activeDetail,
                onOpenRoute: widget.onOpenRoute,
              )
            else
              _RouteFirstCard(
                controller: controller,
                suggested: suggested,
                onOpenRoute: widget.onOpenRoute,
              ),

            if (controller.jornadaActiva && !paused) ...[
              const SizedBox(height: 12),
              _QuickActions(
                onRoute: widget.onOpenRoute,
                onPause: controller.pausarJornada,
                onFinish: _finishDay,
                busy: controller.isSubmitting.value,
              ),
            ],

            if (controller.pendientesOffline > 0) ...[
              const SizedBox(height: 12),
              _FriendlyOfflineNotice(pending: controller.pendientesOffline),
            ],
          ],
        ),
      );
    });
  }
}

class _SimpleDayHeader extends StatelessWidget {
  const _SimpleDayHeader({
    required this.done,
    required this.pending,
    required this.total,
    required this.active,
    required this.paused,
  });

  final int done;
  final int pending;
  final int total;
  final bool active;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : done / total;
    final color = !active
        ? SigmaColors.secondary
        : paused
        ? SigmaColors.warning
        : SigmaColors.success;
    final status = !active
        ? 'Por iniciar'
        : paused
        ? 'Pausada'
        : 'En curso';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mi día',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            minHeight: 8,
            value: progress,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _HeaderStat(value: '$done', label: 'Hechas'),
              _HeaderStat(value: '$pending', label: 'Faltan'),
              _HeaderStat(value: '$total', label: 'Total'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionCard extends StatelessWidget {
  const _PrimaryActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.buttonIcon,
    required this.enabled,
    required this.onPressed,
    this.secondaryText,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonText;
  final IconData buttonIcon;
  final bool enabled;
  final Future<void> Function() onPressed;
  final String? secondaryText;
  final Future<void> Function()? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: SigmaColors.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SigmaColors.primary.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 38, color: SigmaColors.primary),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: enabled ? onPressed : null,
              icon: Icon(buttonIcon),
              label: Text(buttonText),
            ),
          ),
          if (secondaryText != null && onSecondary != null) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onSecondary,
                child: Text(secondaryText!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteFirstCard extends StatelessWidget {
  const _RouteFirstCard({
    required this.controller,
    required this.suggested,
    required this.onOpenRoute,
  });

  final VisitadorOperativoController controller;
  final Map<String, dynamic>? suggested;
  final VoidCallback? onOpenRoute;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SigmaColors.primary.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.map_rounded, color: SigmaColors.primary),
              SizedBox(width: 8),
              Text(
                'Elige tu próxima visita',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            suggested == null
                ? 'Abre Mi ruta para ver los puntos disponibles.'
                : '${controller.clienteNombre(suggested!)} está a ${controller.distanciaDetalleLabel(suggested!)} y es la opción más cercana.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onOpenRoute,
              icon: const Icon(Icons.route_rounded),
              label: const Text('Abrir Mi ruta'),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'La recomendación es solo una ayuda: puedes elegir cualquier punto.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveVisitCard extends StatelessWidget {
  const _ActiveVisitCard({
    required this.controller,
    required this.detail,
    required this.onOpenRoute,
  });

  final VisitadorOperativoController controller;
  final Map<String, dynamic> detail;
  final VoidCallback? onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final near = controller.detalleDentroDeRadio(detail);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SigmaColors.secondary.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Visita pendiente de registro',
            style: TextStyle(
              color: SigmaColors.secondary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            controller.clienteNombre(detail),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            controller.clienteDireccion(detail),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TinyInfo(
                  icon: Icons.directions_walk_rounded,
                  label: controller.distanciaDetalleLabel(detail),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TinyInfo(
                  icon: near
                      ? Icons.check_circle_rounded
                      : Icons.location_searching_rounded,
                  label: near ? 'Ya llegaste' : 'En camino',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (near)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: SigmaColors.success,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _showVisitDialog(context, controller, detail),
                icon: const Icon(Icons.medical_services_outlined),
                label: const Text('Registrar visita'),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOpenRoute,
                icon: const Icon(Icons.map_rounded),
                label: const Text('Volver a Mi ruta'),
              ),
            ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: controller.descartarVisitaActiva,
              child: const Text('Cancelar esta visita'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyInfo extends StatelessWidget {
  const _TinyInfo({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: SigmaColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onRoute,
    required this.onPause,
    required this.onFinish,
    required this.busy,
  });

  final VoidCallback? onRoute;
  final Future<void> Function() onPause;
  final Future<void> Function() onFinish;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onRoute,
            icon: const Icon(Icons.map_outlined),
            label: const Text('Mi ruta'),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: busy ? null : onPause,
            icon: const Icon(Icons.pause_rounded),
            label: const Text('Pausar'),
          ),
        ),
        const SizedBox(width: 7),
        IconButton.outlined(
          tooltip: 'Finalizar jornada',
          onPressed: busy ? null : onFinish,
          icon: const Icon(Icons.flag_outlined),
        ),
      ],
    );
  }
}

class _FriendlyOfflineNotice extends StatelessWidget {
  const _FriendlyOfflineNotice({required this.pending});

  final int pending;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SigmaColors.warning.withOpacity(0.09),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: SigmaColors.warning),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '$pending registro${pending == 1 ? '' : 's'} pendiente${pending == 1 ? '' : 's'} de envío. '
              'Se enviarán automáticamente cuando haya conexión.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({
    required this.total,
    required this.done,
    required this.pending,
    required this.progress,
    required this.active,
    required this.paused,
  });

  final int total;
  final int done;
  final int pending;
  final double progress;
  final bool active;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date = DateFormat('dd MMM').format(now);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hoy · $date',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      !active
                          ? 'Tu jornada de hoy'
                          : paused
                          ? 'Jornada pausada'
                          : 'Tu jornada está en curso',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBubble(
                icon: active
                    ? Icons.location_on_rounded
                    : Icons.schedule_rounded,
                label: !active
                    ? 'Por iniciar'
                    : paused
                    ? 'Pausada'
                    : 'Activo',
                active: active && !paused,
              ),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: progress,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  value: '$done',
                  label: 'Realizadas',
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              Expanded(
                child: _MiniStat(
                  value: '$pending',
                  label: 'Pendientes',
                  icon: Icons.schedule_outlined,
                ),
              ),
              Expanded(
                child: _MiniStat(
                  value: '$total',
                  label: 'Total',
                  icon: Icons.route_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBubble extends StatelessWidget {
  const _StatusBubble({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? SigmaColors.success : SigmaColors.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 19, color: SigmaColors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StartDayCard extends StatelessWidget {
  const _StartDayCard({required this.controller, required this.onOpenRoute});

  final VisitadorOperativoController controller;
  final VoidCallback? onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final hasRoute = controller.tieneRuta;
    final total = controller.detallesRuta.length;

    return _FeedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionEyebrow(
            icon: Icons.wb_sunny_outlined,
            text: 'EMPEZAR EL DÍA',
          ),
          const SizedBox(height: 10),
          Text(
            hasRoute
                ? 'Tienes $total visita${total == 1 ? '' : 's'} programada${total == 1 ? '' : 's'}'
                : 'Aún no tienes visitas asignadas',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            hasRoute
                ? 'Al iniciar se activará tu ubicación y abriremos Mi ruta con todos los puntos. La app marcará el más cercano, pero tú podrás elegir cualquiera.'
                : 'Cuando tu supervisor prepare la ruta, aparecerá aquí automáticamente.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (hasRoute) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: controller.isSubmitting.value
                    ? null
                    : () async {
                        await controller.iniciarJornada();
                        if (controller.jornadaActiva) {
                          onOpenRoute?.call();
                        }
                      },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Iniciar jornada'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PausedJornadaCard extends StatelessWidget {
  const _PausedJornadaCard({
    required this.controller,
    required this.onOpenRoute,
    required this.onFinish,
  });

  final VisitadorOperativoController controller;
  final VoidCallback? onOpenRoute;
  final Future<void> Function() onFinish;

  @override
  Widget build(BuildContext context) {
    return _FeedCard(
      emphasized: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionEyebrow(
            icon: Icons.pause_circle_outline_rounded,
            text: 'JORNADA PAUSADA',
          ),
          const SizedBox(height: 10),
          Text(
            'Tu ubicación está detenida temporalmente',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Úsalo para un descanso, ir al baño u otra interrupción. Tu jornada sigue abierta.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: controller.isSubmitting.value
                  ? null
                  : () async {
                      await controller.reanudarJornada();
                      if (!controller.jornadaPausada.value) {
                        onOpenRoute?.call();
                      }
                    },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Reanudar jornada'),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onFinish,
              child: const Text('Finalizar jornada'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedVisitCard extends StatelessWidget {
  const _SuggestedVisitCard({
    required this.controller,
    required this.detail,
    required this.onOpenRoute,
  });

  final VisitadorOperativoController controller;
  final Map<String, dynamic> detail;
  final VoidCallback? onOpenRoute;

  @override
  Widget build(BuildContext context) {
    return _FeedCard(
      emphasized: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionEyebrow(
            icon: Icons.auto_awesome_rounded,
            text: 'RECOMENDADA POR CERCANÍA',
          ),
          const SizedBox(height: 10),
          Text(
            controller.clienteNombre(detail),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            controller.clienteTipo(detail),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 13),
          _VisitMeta(
            icon: Icons.directions_walk_rounded,
            text: controller.distanciaDetalleLabel(detail),
            strong: true,
          ),
          const SizedBox(height: 7),
          _VisitMeta(
            icon: Icons.place_outlined,
            text: controller.clienteDireccion(detail),
          ),
          const SizedBox(height: 7),
          _VisitMeta(
            icon: Icons.schedule_outlined,
            text: 'Planificada: ${controller.horaPlanificada(detail)}',
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onOpenRoute,
              icon: const Icon(Icons.map_rounded),
              label: const Text('Abrir Mi ruta'),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Es la más cercana, pero puedes elegir otro punto desde el mapa.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentVisitCard extends StatelessWidget {
  const _CurrentVisitCard({
    required this.controller,
    required this.detail,
    required this.onOpenRoute,
  });

  final VisitadorOperativoController controller;
  final Map<String, dynamic> detail;
  final VoidCallback? onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final near = controller.detalleDentroDeRadio(detail);

    return _FeedCard(
      emphasized: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionEyebrow(
            icon: Icons.navigation_rounded,
            text: 'VISITA EN CURSO',
          ),
          const SizedBox(height: 10),
          Text(
            controller.clienteNombre(detail),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            controller.clienteDireccion(detail),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  icon: Icons.directions_walk_rounded,
                  label: 'Distancia',
                  value: controller.distanciaDetalleLabel(detail),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _InfoTile(
                  icon: near
                      ? Icons.check_circle_rounded
                      : Icons.location_searching_rounded,
                  label: 'Estado',
                  value: near ? 'Ya llegaste' : 'En camino',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!near) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SigmaColors.secondary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: SigmaColors.secondary,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Acércate al punto de visita. El registro se habilitará cuando estés dentro del radio permitido.',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 11),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOpenRoute,
                icon: const Icon(Icons.map_rounded),
                label: const Text('Ver en Mi ruta'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: controller.actualizarUbicacionOperativa,
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Comprobar mi ubicación'),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SigmaColors.success.withOpacity(0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: SigmaColors.success),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Llegaste al punto. Ya puedes registrar el resultado de la visita.',
                      style: TextStyle(
                        color: SigmaColors.success,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 11),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: SigmaColors.success,
                  foregroundColor: Colors.white,
                ),
                onPressed: controller.isSubmitting.value
                    ? null
                    : () => _showVisitDialog(context, controller, detail),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Registrar resultado'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NextVisitsFeed extends StatelessWidget {
  const _NextVisitsFeed({required this.controller, required this.excluded});

  final VisitadorOperativoController controller;
  final Map<String, dynamic> excluded;

  @override
  Widget build(BuildContext context) {
    final rows = controller.detallesRutaOrdenados
        .where(
          (item) =>
              !controller.detalleVisitado(item) &&
              !controller.esMismoDetalle(item, excluded) &&
              !controller.esDetalleVisitaActiva(item),
        )
        .take(3)
        .toList();

    if (rows.isEmpty) return const SizedBox.shrink();

    return _FeedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Después',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            'Tus siguientes visitas por cercanía',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < rows.length; i++) ...[
            _CompactVisitRow(
              index: i + 2,
              controller: controller,
              detail: rows[i],
            ),
            if (i != rows.length - 1) const Divider(height: 20),
          ],
        ],
      ),
    );
  }
}

class _CompactVisitRow extends StatelessWidget {
  const _CompactVisitRow({
    required this.index,
    required this.controller,
    required this.detail,
  });

  final int index;
  final VisitadorOperativoController controller;
  final Map<String, dynamic> detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: SigmaColors.primary.withOpacity(0.09),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$index',
            style: const TextStyle(
              color: SigmaColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                controller.clienteNombre(detail),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                controller.clienteDireccion(detail),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          controller.distanciaDetalleLabel(detail),
          style: const TextStyle(
            color: SigmaColors.secondary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.controller});

  final VisitadorOperativoController controller;

  @override
  Widget build(BuildContext context) {
    final count = controller.pendientesOffline;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: SigmaColors.warning.withOpacity(0.10),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: SigmaColors.warning),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '$count registro${count == 1 ? '' : 's'} esperando conexión. '
              'La aplicación los enviará cuando sea posible.',
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllDoneCard extends StatelessWidget {
  const _AllDoneCard();

  @override
  Widget build(BuildContext context) {
    return _FeedCard(
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: SigmaColors.success.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.done_all_rounded,
              color: SigmaColors.success,
              size: 30,
            ),
          ),
          const SizedBox(height: 11),
          Text(
            'Completaste tus visitas',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            'Ya no tienes visitas pendientes en la ruta de hoy.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.child, this.emphasized = false});

  final Widget child;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: emphasized
              ? SigmaColors.primary.withOpacity(0.24)
              : Theme.of(context).dividerColor.withOpacity(0.12),
          width: emphasized ? 1.3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: SigmaColors.primary),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: SigmaColors.primary,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _VisitMeta extends StatelessWidget {
  const _VisitMeta({
    required this.icon,
    required this.text,
    this.strong = false,
  });

  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: strong
              ? SigmaColors.secondary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: strong
                  ? SigmaColors.secondary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: SigmaColors.primary),
          const SizedBox(height: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _OperationHeader extends StatelessWidget {
  const _OperationHeader({required this.controller});
  final VisitadorOperativoController controller;

  @override
  Widget build(BuildContext context) {
    final active = controller.jornadaActiva;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: active ? SigmaGradients.primary : SigmaGradients.dark,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: (active ? SigmaColors.primary : Colors.black).withOpacity(
              0.22,
            ),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.medical_services_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mi jornada de hoy',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      controller.tieneRuta
                          ? '${controller.rutaNombre} · ${controller.zonaNombre}'
                          : 'Todavía no tienes una ruta asignada para hoy',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.88),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeaderPill(
                label: active ? 'Jornada en curso' : 'Jornada sin iniciar',
                icon: Icons.schedule,
              ),
              _HeaderPill(
                label: controller.isGpsTracking.value
                    ? 'Ubicación activa'
                    : 'Ubicación pendiente',
                icon: controller.isGpsTracking.value
                    ? Icons.location_on_outlined
                    : Icons.location_off_outlined,
              ),
              _HeaderPill(
                label:
                    '${controller.visitasRealizadas}/${controller.detallesRuta.length} visitas',
                icon: Icons.fact_check_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegacyActiveVisitCard extends StatelessWidget {
  const _LegacyActiveVisitCard({required this.controller});

  final VisitadorOperativoController controller;

  @override
  Widget build(BuildContext context) {
    final draft = controller.visitaActiva.value;
    if (draft == null) return const SizedBox.shrink();

    final elapsed = controller.visitaActivaDuracion;
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60);
    final durationText = hours > 0
        ? '${hours}h ${minutes}min'
        : '${minutes}min';

    return SigmaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: SigmaColors.warning.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.pending_actions_rounded,
                  color: SigmaColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Visita en curso',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      controller.visitaActivaClienteNombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              SigmaPill(
                label: durationText,
                icon: Icons.timer_outlined,
                color: SigmaColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Iniciada a las ${controller.visitaActivaInicioLabel}. Puedes continuarla cuando estés listo.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: controller.isSubmitting.value
                      ? null
                      : () => _showVisitDialog(
                          context,
                          controller,
                          draft.detalleRuta,
                        ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Continuar visita'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: 'Descartar borrador',
                onPressed: controller.isSubmitting.value
                    ? null
                    : () => _confirmarDescartarVisita(context, controller),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SyncPendientesCard extends StatelessWidget {
  const _SyncPendientesCard({required this.controller});
  final VisitadorOperativoController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pendientes = controller.pendientesOffline;
      final sincronizando = controller.sincronizandoOffline;
      final hayPendientes = pendientes > 0;

      if (!hayPendientes && !sincronizando) {
        return const SizedBox.shrink();
      }

      return SigmaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hayPendientes
                      ? Icons.sync_problem_rounded
                      : Icons.cloud_done_outlined,
                  color: hayPendientes
                      ? SigmaColors.warning
                      : SigmaColors.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hayPendientes
                        ? '$pendientes registro(s) esperando conexión'
                        : 'Actualizando información',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              controller.mensajeSyncOffline,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: sincronizando
                        ? null
                        : controller.actualizarPendientesOffline,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Revisar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: !hayPendientes || sincronizando
                        ? null
                        : controller.sincronizarPendientesOffline,
                    icon: sincronizando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(
                      sincronizando ? 'Enviando...' : 'Intentar enviar',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _JornadaActions extends StatelessWidget {
  const _JornadaActions({required this.controller});
  final VisitadorOperativoController controller;

  @override
  Widget build(BuildContext context) {
    return SigmaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.today_outlined, color: SigmaColors.primary),
              const SizedBox(width: 8),
              Text(
                'Mi jornada',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.observacionJornadaController,
            minLines: 1,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Nota del día',
              hintText: 'Opcional',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      controller.isSubmitting.value || controller.jornadaActiva
                      ? null
                      : controller.iniciarJornada,
                  icon: const Icon(Icons.gps_fixed_rounded),
                  label: Text(
                    controller.jornadaCerrada
                        ? 'Iniciar nuevamente'
                        : 'Iniciar jornada',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      controller.isSubmitting.value || !controller.jornadaActiva
                      ? null
                      : () => _confirmarCierreJornada(context, controller),
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Finalizar jornada'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Obx(() {
            final pos = controller.lastPosition.value;
            final ubicacionLista =
                controller.isGpsTracking.value || pos != null;
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SigmaColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(
                    controller.isGpsTracking.value
                        ? Icons.location_on_rounded
                        : Icons.location_off_outlined,
                    color: controller.isGpsTracking.value
                        ? SigmaColors.success
                        : SigmaColors.secondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ubicacionLista
                              ? 'Ubicación activa'
                              : 'Ubicación pendiente',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          ubicacionLista
                              ? 'SIGPRED está registrando tu recorrido durante la jornada.'
                              : 'La ubicación se activará al iniciar tu jornada.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RouteList extends StatelessWidget {
  const _RouteList({required this.controller});
  final VisitadorOperativoController controller;

  @override
  Widget build(BuildContext context) {
    final detalles = controller.detallesRutaOrdenados;
    if (!controller.tieneRuta) {
      return const _EmptyState(
        icon: Icons.route_outlined,
        title: 'Aún no tienes visitas asignadas',
        message:
            'Cuando tu supervisor prepare tu ruta, tus visitas aparecerán aquí automáticamente.',
      );
    }

    if (detalles.isEmpty) {
      return const _EmptyState(
        icon: Icons.location_off_outlined,
        title: 'No hay visitas programadas',
        message:
            'Tu ruta está creada, pero todavía no tiene visitas programadas.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Sugeridos para ti',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        ...detalles.map(
          (detalle) =>
              _RoutePointCard(controller: controller, detalle: detalle),
        ),
      ],
    );
  }
}

class _RoutePointCard extends StatelessWidget {
  const _RoutePointCard({required this.controller, required this.detalle});

  final VisitadorOperativoController controller;
  final Map<String, dynamic> detalle;

  @override
  Widget build(BuildContext context) {
    final visitado = controller.detalleVisitado(detalle);
    final revisitable = controller.detalleRevisitable(detalle);
    final efectiva = controller.detalleVisitaEfectiva(detalle);
    final motivo = controller.detalleMotivoVisita(detalle);
    final activa = controller.esDetalleVisitaActiva(detalle);
    final bloqueadaPorOtra = controller.tieneVisitaActiva && !activa;
    final dentroDelRadio = controller.detalleDentroDeRadio(detalle);
    final distancia = controller.distanciaDetalleLabel(detalle);
    final sugerida =
        !visitado &&
        controller.siguienteVisitaSugerida != null &&
        controller.esMismoDetalle(detalle, controller.siguienteVisitaSugerida!);

    return SigmaCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      (visitado && !efectiva
                              ? SigmaColors.warning
                              : visitado
                              ? SigmaColors.success
                              : activa
                              ? SigmaColors.secondary
                              : SigmaColors.primary)
                          .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  revisitable
                      ? Icons.refresh_rounded
                      : visitado && !efectiva
                      ? Icons.remove_shopping_cart_outlined
                      : visitado
                      ? Icons.check_rounded
                      : activa
                      ? Icons.navigation_rounded
                      : Icons.place_outlined,
                  color: visitado && !efectiva
                      ? SigmaColors.warning
                      : visitado
                      ? SigmaColors.success
                      : activa
                      ? SigmaColors.secondary
                      : SigmaColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (sugerida && !activa)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(
                          'MÁS CERCANA',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: SigmaColors.primary,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .7,
                              ),
                        ),
                      ),
                    Text(
                      controller.clienteNombre(detalle),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${controller.clienteTipo(detalle)} · '
                      '${controller.clienteDireccion(detalle)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!visitado || revisitable) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.near_me_outlined,
                            size: 17,
                            color: SigmaColors.secondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            distancia,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                    if (visitado && !efectiva && motivo.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        'Último resultado: $motivo',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: SigmaColors.warning,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (visitado)
                SigmaPill(
                  label: efectiva ? 'Efectiva' : 'No efectiva',
                  icon: revisitable
                      ? Icons.refresh_rounded
                      : efectiva
                      ? Icons.done
                      : Icons.remove_shopping_cart_outlined,
                  color: efectiva ? SigmaColors.success : SigmaColors.warning,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (visitado && !revisitable)
            const SizedBox.shrink()
          else if (!controller.jornadaActiva)
            const _VisitGuideMessage(
              icon: Icons.play_circle_outline_rounded,
              text: 'Inicia tu jornada para comenzar las visitas.',
            )
          else if (bloqueadaPorOtra)
            const _VisitGuideMessage(
              icon: Icons.info_outline_rounded,
              text: 'Primero termina la visita que tienes en curso.',
            )
          else if (!activa && revisitable && !dentroDelRadio) ...[
            _VisitGuideMessage(
              icon: Icons.directions_walk_rounded,
              text:
                  'Esta visita quedó no efectiva. Acércate nuevamente al punto '
                  'para poder volver a visitarla.',
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: controller.actualizarUbicacionOperativa,
              icon: const Icon(Icons.my_location_rounded),
              label: const Text('Comprobar mi ubicación'),
            ),
          ] else if (!activa && revisitable)
            FilledButton.icon(
              onPressed: controller.isSubmitting.value
                  ? null
                  : () => controller.iniciarORecuperarVisita(
                      detalle,
                      revisita: true,
                    ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Volver a visitar'),
              style: FilledButton.styleFrom(
                backgroundColor: SigmaColors.warning,
                foregroundColor: Colors.white,
              ),
            )
          else if (!activa)
            FilledButton.icon(
              onPressed: controller.isSubmitting.value
                  ? null
                  : () => controller.iniciarORecuperarVisita(detalle),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Iniciar visita'),
            )
          else if (!dentroDelRadio) ...[
            const _VisitGuideMessage(
              icon: Icons.directions_walk_rounded,
              text:
                  'Dirígete al punto marcado en Mi ruta. Cuando estés cerca, '
                  'se habilitará el registro del resultado.',
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: controller.actualizarUbicacionOperativa,
              icon: const Icon(Icons.my_location_rounded),
              label: const Text('Comprobar mi ubicación'),
            ),
          ] else ...[
            const _VisitGuideMessage(
              icon: Icons.check_circle_rounded,
              text: 'Llegaste al punto. Ya puedes registrar el resultado.',
              success: true,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: controller.isSubmitting.value
                  ? null
                  : () => _showVisitDialog(context, controller, detalle),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Registrar resultado'),
              style: FilledButton.styleFrom(
                backgroundColor: SigmaColors.success,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VisitGuideMessage extends StatelessWidget {
  const _VisitGuideMessage({
    required this.icon,
    required this.text,
    this.success = false,
  });

  final IconData icon;
  final String text;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final color = success ? SigmaColors.success : SigmaColors.secondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SigmaCard(
      child: Column(
        children: [
          Icon(icon, size: 48, color: SigmaColors.primary),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// SIGPRED 10.25 - UX móvil validaciones visibles
Future<void> _showVisitDialog(
  BuildContext context,
  VisitadorOperativoController controller,
  Map<String, dynamic> detalle,
) async {
  const motivoSinPedido = 'Sin pedido / atención realizada';
  const motivoCerrado = 'Cliente cerrado';
  const motivoAusente = 'Cliente o encargado ausente';
  const motivoNoDisponible = 'No disponible para atención';
  const motivoReprogramada = 'Visita reprogramada';
  const motivoOtro = 'Otro';
  const motivos = <String>[
    motivoSinPedido,
    motivoCerrado,
    motivoAusente,
    motivoNoDisponible,
    motivoReprogramada,
    motivoOtro,
  ];

  final draft = await controller.iniciarORecuperarVisita(detalle);
  if (!context.mounted || draft == null) return;

  final fechaInicio = draft.fechaInicio;
  final observacionesController = TextEditingController(
    text: draft.observaciones,
  );
  final firmaNombreController = TextEditingController(
    text: draft.firmaNombre ?? '',
  );
  final cantidadController = TextEditingController(text: '1');
  final precioController = TextEditingController(text: '0');

  bool generaPedido = draft.efectiva || draft.pedidoItems.isNotEmpty;
  String motivoSeleccionado = motivos.contains(draft.motivo)
      ? draft.motivo
      : '';
  String firmaRol =
      <String>['Doctor', 'Encargado', 'Otro'].contains(draft.firmaRol)
      ? draft.firmaRol!
      : 'Doctor';
  String? firmaBase64 = draft.firmaBase64;
  DateTime? firmaCapturedAt = draft.firmaCapturedAt;
  int? productoId;
  DateTime? fechaEntrega = draft.fechaEntrega;
  final pedidoItems = List<PedidoItemDraft>.from(draft.pedidoItems);

  bool requiereFirma() => generaPedido || motivoSeleccionado == motivoSinPedido;

  void persistir() {
    controller.actualizarBorradorVisita(
      tipoAtencion: 'Presencial',
      efectiva: generaPedido,
      resultado: generaPedido ? 'Pedido generado' : motivoSeleccionado,
      motivo: generaPedido ? '' : motivoSeleccionado,
      observaciones: observacionesController.text,
      pedidoItems: List<PedidoItemDraft>.from(pedidoItems),
      fechaEntrega: fechaEntrega,
      clearFechaEntrega: fechaEntrega == null,
      firmaBase64: firmaBase64,
      clearFirma: firmaBase64 == null || firmaBase64!.isEmpty,
      firmaNombre: firmaNombreController.text,
      firmaRol: firmaRol,
      firmaCapturedAt: firmaCapturedAt,
    );
  }

  observacionesController.addListener(persistir);
  firmaNombreController.addListener(persistir);

  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottom = MediaQuery.of(context).viewInsets.bottom;
            final totalPedido = pedidoItems.fold<double>(
              0,
              (total, item) => total + item.subtotal,
            );

            // SIGPRED 10.25 - UX móvil validaciones visibles
            void mostrarError(String message) {
              if (Get.isSnackbarOpen) {
                Get.closeCurrentSnackbar();
              }
              Get.snackbar(
                'Revisa el pedido',
                message,
                snackPosition: SnackPosition.TOP,
                margin: const EdgeInsets.all(12),
                borderRadius: 14,
                duration: const Duration(seconds: 5),
                backgroundColor: SigmaColors.danger,
                colorText: Colors.white,
                icon: const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white,
                ),
                shouldIconPulse: false,
              );
            }

            void mostrarExito(String message) {
              if (Get.isSnackbarOpen) {
                Get.closeCurrentSnackbar();
              }
              Get.snackbar(
                'Producto agregado',
                message,
                snackPosition: SnackPosition.TOP,
                margin: const EdgeInsets.all(12),
                borderRadius: 14,
                duration: const Duration(seconds: 3),
                backgroundColor: SigmaColors.success,
                colorText: Colors.white,
                icon: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.white,
                ),
                shouldIconPulse: false,
              );
            }

            void guardarEstado() => persistir();

            void limpiarFirma() {
              setSheetState(() {
                firmaBase64 = null;
                firmaCapturedAt = null;
                firmaNombreController.clear();
                firmaRol = 'Doctor';
              });
              guardarEstado();
            }

            void agregarProducto() {
              if (productoId == null) {
                mostrarError('Selecciona un producto.');
                return;
              }

              final cantidadTexto = cantidadController.text.trim();
              if (cantidadTexto.isEmpty) {
                mostrarError('Ingresa la cantidad que deseas agregar.');
                return;
              }

              final cantidad = int.tryParse(cantidadTexto);
              if (cantidad == null) {
                mostrarError(
                  'La cantidad debe ser un número entero, por ejemplo 1, 25 o 10000.',
                );
                return;
              }

              if (cantidad <= 0) {
                mostrarError('La cantidad debe ser mayor a 0.');
                return;
              }
              Map<String, dynamic>? producto;
              for (final item in controller.productos) {
                if (item['producto_id'].toString() == productoId.toString()) {
                  producto = item;
                  break;
                }
              }

              if (producto == null) {
                mostrarError('No se encontró el producto seleccionado.');
                return;
              }

              // El precio del pedido siempre proviene del catálogo cargado por
              // Administración. El Visitador no puede ingresarlo ni modificarlo.
              final precio = controller.productoPrecio(producto);
              if (precio <= 0) {
                mostrarError(
                  'El precio del producto debe ser revisado por el administrador.',
                );
                return;
              }

              final disponibilidad = controller.productoDisponibilidad(
                producto,
              );
              if (disponibilidad == null) {
                mostrarError(
                  'Disponibilidad sin configurar. Solicita revisión al administrador.',
                );
                return;
              }
              if (cantidad > disponibilidad) {
                mostrarError('Solo hay $disponibilidad unidades disponibles.');
                return;
              }

              final duplicatedIndex = pedidoItems.indexWhere(
                (item) => item.productoId == productoId,
              );

              final itemDraft = PedidoItemDraft(
                productoId: productoId!,
                productoNombre: controller.productoNombre(producto),
                cantidad: cantidad,
                precioUnitario: precio,
              );

              setSheetState(() {
                if (duplicatedIndex >= 0) {
                  pedidoItems[duplicatedIndex] = itemDraft;
                } else {
                  pedidoItems.add(itemDraft);
                }
                productoId = null;
                cantidadController.text = '1';
                precioController.text = '0';
              });
              guardarEstado();
              mostrarExito(
                'El producto quedó agregado al pedido. Puedes continuar o registrar la visita.',
              );
            }

            Widget firmaSection() {
              if (!requiereFirma()) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: SigmaColors.primary.withOpacity(.09),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.draw_outlined,
                          color: SigmaColors.primary,
                        ),
                      ),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Conformidad de la atención',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'El doctor o encargado firma en una pantalla exclusiva.',
                              style: TextStyle(
                                color: Color(0xFF667085),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: firmaNombreController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de quien firma',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: firmaRol,
                    decoration: const InputDecoration(
                      labelText: 'Responsable',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Doctor', child: Text('Doctor')),
                      DropdownMenuItem(
                        value: 'Encargado',
                        child: Text('Encargado'),
                      ),
                      DropdownMenuItem(
                        value: 'Otro',
                        child: Text('Otro responsable'),
                      ),
                    ],
                    onChanged: (value) {
                      setSheetState(() => firmaRol = value ?? 'Doctor');
                      guardarEstado();
                    },
                  ),
                  const SizedBox(height: 11),
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color:
                          firmaBase64 != null && firmaBase64!.trim().isNotEmpty
                          ? const Color(0xFFECFDF3)
                          : const Color(0xFFFFFAEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            firmaBase64 != null &&
                                firmaBase64!.trim().isNotEmpty
                            ? const Color(0xFFA6F4C5)
                            : const Color(0xFFFEDF89),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color:
                                firmaBase64 != null &&
                                    firmaBase64!.trim().isNotEmpty
                                ? const Color(0xFFD1FADF)
                                : const Color(0xFFFEF0C7),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            firmaBase64 != null &&
                                    firmaBase64!.trim().isNotEmpty
                                ? Icons.verified_rounded
                                : Icons.edit_rounded,
                            color:
                                firmaBase64 != null &&
                                    firmaBase64!.trim().isNotEmpty
                                ? const Color(0xFF039855)
                                : const Color(0xFFDC6803),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                firmaBase64 != null &&
                                        firmaBase64!.trim().isNotEmpty
                                    ? 'Firma confirmada'
                                    : 'Firma pendiente',
                                style: TextStyle(
                                  color:
                                      firmaBase64 != null &&
                                          firmaBase64!.trim().isNotEmpty
                                      ? const Color(0xFF027A48)
                                      : const Color(0xFFB54708),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                firmaBase64 != null &&
                                        firmaBase64!.trim().isNotEmpty
                                    ? 'Puedes editarla antes de registrar la visita.'
                                    : 'Abre la pantalla de firma para evitar '
                                          'desplazamientos accidentales.',
                                style: const TextStyle(
                                  color: Color(0xFF667085),
                                  fontSize: 10.5,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 42),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: () async {
                            FocusScope.of(sheetContext).unfocus();

                            final result = await showVisitadorSignatureCapture(
                              sheetContext,
                              initialBase64: firmaBase64,
                              signerRole: firmaRol,
                            );

                            if (result == null || !sheetContext.mounted) {
                              return;
                            }

                            setSheetState(() {
                              firmaBase64 = result.base64;
                              firmaCapturedAt = result.capturedAt;
                            });
                            guardarEstado();
                          },
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: Text(
                            firmaBase64 != null &&
                                    firmaBase64!.trim().isNotEmpty
                                ? 'Editar'
                                : 'Firmar',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Registrar visita médica',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${controller.clienteNombre(detalle)} · Inicio: ${DateFormat('HH:mm').format(fechaInicio)}',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Descartar visita',
                          onPressed: () async {
                            final descartada = await _confirmarDescartarVisita(
                              sheetContext,
                              controller,
                            );
                            if (descartada && sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest.withOpacity(.45),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.handshake_outlined, size: 20),
                          SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Visita presencial',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  'El tipo de visita es fijo para el proceso de visita médica.',
                                  style: TextStyle(fontSize: 10.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '¿Se generó un pedido?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SIGPRED determina la efectividad a partir del pedido.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: _VisitResultChoice(
                            selected: generaPedido,
                            color: SigmaColors.success,
                            icon: Icons.shopping_cart_checkout_rounded,
                            title: 'Sí, con pedido',
                            subtitle: 'Visita efectiva',
                            onTap: () {
                              setSheetState(() {
                                generaPedido = true;
                                motivoSeleccionado = '';
                              });
                              guardarEstado();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _VisitResultChoice(
                            selected: !generaPedido,
                            color: SigmaColors.danger,
                            icon: Icons.remove_shopping_cart_outlined,
                            title: 'No hubo pedido',
                            subtitle: 'Visita no efectiva',
                            onTap: () {
                              setSheetState(() {
                                generaPedido = false;
                                pedidoItems.clear();
                                fechaEntrega = null;
                              });
                              guardarEstado();
                            },
                          ),
                        ),
                      ],
                    ),
                    if (!generaPedido) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Motivo principal',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Selecciona una sola opción para mantener reportes consistentes.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 7),
                      ...motivos.map(
                        (motivo) => RadioListTile<String>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: motivo,
                          groupValue: motivoSeleccionado,
                          title: Text(
                            motivo,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: motivo == motivoSinPedido
                              ? const Text('Requiere firma de conformidad.')
                              : motivo == motivoOtro
                              ? const Text('Requiere una observación.')
                              : null,
                          onChanged: (value) {
                            final selected = value ?? '';
                            final shouldKeepSignature =
                                selected == motivoSinPedido;
                            setSheetState(() {
                              motivoSeleccionado = selected;
                              if (!shouldKeepSignature) {
                                firmaBase64 = null;
                                firmaCapturedAt = null;
                                firmaNombreController.clear();
                                firmaRol = 'Doctor';
                              }
                            });
                            guardarEstado();
                          },
                        ),
                      ),
                    ],
                    if (generaPedido) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Pedido',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Agrega al menos un producto para registrar la visita como efectiva.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        value: productoId,
                        decoration: const InputDecoration(
                          labelText: 'Producto',
                          prefixIcon: Icon(Icons.medication_outlined),
                        ),
                        items: controller.productos
                            .map(
                              (producto) => DropdownMenuItem<int>(
                                value: producto['producto_id'] is int
                                    ? producto['producto_id'] as int
                                    : int.tryParse(
                                        producto['producto_id'].toString(),
                                      ),
                                child: Text(
                                  controller.productoNombre(producto),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .where((item) => item.value != null)
                            .toList(),
                        onChanged: (value) {
                          Map<String, dynamic>? selected;
                          for (final producto in controller.productos) {
                            if (producto['producto_id'].toString() ==
                                value.toString()) {
                              selected = producto;
                              break;
                            }
                          }
                          setSheetState(() {
                            productoId = value;
                            if (selected != null) {
                              precioController.text = controller
                                  .productoPrecio(selected)
                                  .toStringAsFixed(2);
                            }
                          });
                        },
                      ),
                      if (productoId != null) ...[
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            Map<String, dynamic>? selectedProduct;
                            for (final producto in controller.productos) {
                              if (producto['producto_id'].toString() ==
                                  productoId.toString()) {
                                selectedProduct = producto;
                                break;
                              }
                            }
                            if (selectedProduct == null) {
                              return const SizedBox.shrink();
                            }
                            final available = controller.productoDisponibilidad(
                              selectedProduct,
                            );
                            final configured = available != null;
                            final color = configured && available > 0
                                ? SigmaColors.success
                                : SigmaColors.warning;
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: color.withOpacity(.18),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 20,
                                    color: color,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          configured
                                              ? 'Disponible para pedido: $available unidades'
                                              : 'Disponibilidad por configurar',
                                          style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          controller.isUsingOfflineCache.value
                                              ? 'Última disponibilidad guardada. El sistema la confirmará automáticamente al sincronizar.'
                                              : 'Disponibilidad consultada. El sistema verificará automáticamente la cantidad al registrar el pedido.',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: cantidadController,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Cantidad',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: precioController,
                              readOnly: true,
                              enableInteractiveSelection: false,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Precio unitario',
                                helperText: 'Definido por Administración',
                                suffixIcon: Icon(Icons.lock_outline_rounded),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: agregarProducto,
                          icon: const Icon(Icons.add_shopping_cart_outlined),
                          label: const Text('Agregar producto'),
                        ),
                      ),
                      if (pedidoItems.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ...pedidoItems.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 7),
                            child: ListTile(
                              dense: true,
                              title: Text(item.productoNombre),
                              subtitle: Text(
                                '${item.cantidad} × Bs ${item.precioUnitario.toStringAsFixed(2)}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Bs ${item.subtotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Quitar producto',
                                    onPressed: () {
                                      setSheetState(
                                        () => pedidoItems.removeAt(index),
                                      );
                                      guardarEstado();
                                    },
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Total: Bs ${totalPedido.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_available_outlined),
                        title: const Text('Fecha estimada de entrega'),
                        subtitle: Text(
                          fechaEntrega == null
                              ? 'Seleccionar fecha'
                              : DateFormat('dd/MM/yyyy').format(fechaEntrega!),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          final selected = await showDatePicker(
                            context: sheetContext,
                            initialDate:
                                fechaEntrega ??
                                DateTime.now().add(const Duration(days: 1)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (selected != null) {
                            setSheetState(() => fechaEntrega = selected);
                            guardarEstado();
                          }
                        },
                      ),
                    ],
                    firmaSection(),
                    const SizedBox(height: 16),
                    TextField(
                      controller: observacionesController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: motivoSeleccionado == motivoOtro
                            ? 'Observación *'
                            : 'Observación (opcional)',
                        prefixIcon: const Icon(Icons.notes_outlined),
                        hintText: motivoSeleccionado == motivoOtro
                            ? 'Describe brevemente el motivo.'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Obx(() {
                      return SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: controller.isSubmitting.value
                              ? null
                              : () async {
                                  if (generaPedido && pedidoItems.isEmpty) {
                                    mostrarError(
                                      'Agrega al menos un producto al pedido.',
                                    );
                                    return;
                                  }

                                  if (!generaPedido &&
                                      motivoSeleccionado.isEmpty) {
                                    mostrarError(
                                      'Selecciona el motivo principal.',
                                    );
                                    return;
                                  }

                                  if (!generaPedido &&
                                      motivoSeleccionado == motivoOtro &&
                                      observacionesController.text
                                          .trim()
                                          .isEmpty) {
                                    mostrarError(
                                      'Describe el motivo en Observación.',
                                    );
                                    return;
                                  }

                                  if (pedidoItems.isNotEmpty &&
                                      fechaEntrega == null) {
                                    mostrarError(
                                      'Selecciona la fecha estimada de entrega.',
                                    );
                                    return;
                                  }

                                  if (requiereFirma()) {
                                    if (firmaNombreController.text
                                        .trim()
                                        .isEmpty) {
                                      mostrarError(
                                        'Registra el nombre de quien firma.',
                                      );
                                      return;
                                    }
                                    if (firmaBase64 == null ||
                                        firmaBase64!.trim().isEmpty) {
                                      mostrarError(
                                        'Abre el lápiz y confirma la firma antes de registrar.',
                                      );
                                      return;
                                    }
                                  }

                                  if (!requiereFirma() && firmaBase64 != null) {
                                    limpiarFirma();
                                  }

                                  guardarEstado();
                                  await controller.flushVisitaActiva();

                                  final ok = await controller.registrarVisita(
                                    detalleRuta: detalle,
                                    fechaInicio: fechaInicio,
                                    tipoAtencion: 'Presencial',
                                    efectiva: generaPedido,
                                    resultado: generaPedido
                                        ? 'Pedido generado'
                                        : motivoSeleccionado,
                                    motivo: generaPedido
                                        ? ''
                                        : motivoSeleccionado,
                                    observaciones: observacionesController.text,
                                    pedidoItems: List<PedidoItemDraft>.from(
                                      pedidoItems,
                                    ),
                                    firmaBase64: requiereFirma()
                                        ? firmaBase64
                                        : null,
                                    firmaNombre: requiereFirma()
                                        ? firmaNombreController.text
                                        : '',
                                    firmaRol: requiereFirma() ? firmaRol : '',
                                    firmaCapturedAt: requiereFirma()
                                        ? firmaCapturedAt ?? DateTime.now()
                                        : null,
                                    fechaEntrega: fechaEntrega,
                                  );

                                  if (ok && sheetContext.mounted) {
                                    Navigator.of(sheetContext).pop();
                                  }
                                },
                          icon: controller.isSubmitting.value
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(
                            controller.isSubmitting.value
                                ? 'Guardando...'
                                : 'Registrar visita',
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'El borrador se conserva automáticamente en este teléfono.',
                        style: Theme.of(context).textTheme.labelSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  } finally {
    observacionesController.removeListener(persistir);
    firmaNombreController.removeListener(persistir);

    // showModalBottomSheet puede completar su Future mientras la animación
    // de salida todavía usa los TextField. Mantener vivos los controladores
    // hasta después de esa transición evita:
    // "A TextEditingController was used after being disposed."
    await Future<void>.delayed(const Duration(milliseconds: 420));

    observacionesController.dispose();
    firmaNombreController.dispose();
    cantidadController.dispose();
    precioController.dispose();
  }
}

class _VisitResultChoice extends StatelessWidget {
  const _VisitResultChoice({
    required this.selected,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withOpacity(.09) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : const Color(0xFFD0D5DD),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 5),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> _confirmarDescartarVisita(
  BuildContext context,
  VisitadorOperativoController controller,
) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Descartar visita activa'),
      content: const Text(
        'Se eliminarán la hora de inicio y todos los datos guardados en el borrador. ¿Deseas continuar?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Descartar'),
        ),
      ],
    ),
  );

  if (confirmar == true) {
    await controller.descartarVisitaActiva();
    return true;
  }
  return false;
}

Future<void> _confirmarCierreJornada(
  BuildContext context,
  VisitadorOperativoController controller,
) async {
  if (controller.tieneVisitaActiva) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Existe una visita en curso'),
        content: Text(
          'Finaliza o descarta la visita de ${controller.visitaActivaClienteNombre} antes de cerrar la jornada.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    return;
  }

  if (controller.visitasPendientes == 0) {
    await controller.cerrarJornada();
    return;
  }

  final confirmar = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Quedan visitas pendientes'),
      content: Text(
        'Todavía quedan ${controller.visitasPendientes} punto(s) sin registrar. '
        '¿Deseas cerrar la jornada de todas maneras?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Continuar jornada'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Finalizar jornada'),
        ),
      ],
    ),
  );

  if (confirmar == true) {
    await controller.cerrarJornada();
  }
}
