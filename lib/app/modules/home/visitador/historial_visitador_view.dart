import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../data/models/visita_historial.dart';
import '../../../utils/app_theme.dart';
import 'historial_visitador_controller.dart';

class HistorialVisitadorView extends StatefulWidget {
  const HistorialVisitadorView({super.key});

  @override
  State<HistorialVisitadorView> createState() => _HistorialVisitadorViewState();
}

class _HistorialVisitadorViewState extends State<HistorialVisitadorView> {
  late final HistorialVisitadorController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<HistorialVisitadorController>()
        ? Get.find<HistorialVisitadorController>()
        : Get.put(HistorialVisitadorController());

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => controller.cargarHistorial(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final rows = controller.filteredVisits;

      return RefreshIndicator(
        onRefresh: controller.cargarHistorial,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mis visitas',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Consulta rápidamente lo que hiciste.',
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
                      IconButton.outlined(
                        tooltip: 'Elegir fecha',
                        onPressed: () => controller.pickDate(context),
                        icon: const Icon(Icons.calendar_month_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller.searchController,
                    decoration: const InputDecoration(
                      hintText: 'Buscar médico o cliente',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          controller: controller,
                          value: 'todas',
                          label: 'Todas',
                        ),
                        _FilterChip(
                          controller: controller,
                          value: 'efectivas',
                          label: 'Efectivas',
                        ),
                        _FilterChip(
                          controller: controller,
                          value: 'no_efectivas',
                          label: 'No efectivas',
                        ),
                        _FilterChip(
                          controller: controller,
                          value: 'pendientes',
                          label: 'Por enviar',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _CountCard(
                        value: controller.total,
                        label: 'Total',
                        color: SigmaColors.primary,
                      ),
                      const SizedBox(width: 8),
                      _CountCard(
                        value: controller.efectivas,
                        label: 'Efectivas',
                        color: SigmaColors.success,
                      ),
                      const SizedBox(width: 8),
                      _CountCard(
                        value: controller.noEfectivas,
                        label: 'No efectivas',
                        color: SigmaColors.danger,
                      ),
                    ],
                  ),
                  if (!controller.backendDisponible.value ||
                      controller.pendientes > 0) ...[
                    const SizedBox(height: 10),
                    _DataStatus(
                      offline: !controller.backendDisponible.value,
                      pending: controller.pendientes,
                      onSync: controller.pendientes > 0
                          ? controller.sincronizarPendientes
                          : null,
                    ),
                  ],
                  const SizedBox(height: 8),
                ]),
              ),
            ),
            if (controller.isLoading.value && rows.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (rows.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyHistory(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                sliver: SliverList.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final visita = rows[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _VisitRow(
                        visita: visita,
                        onTap: () => _showDetail(visita),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      );
    });
  }

  void _showDetail(VisitaHistorial visita) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final color = visita.pendienteOffline
            ? SigmaColors.warning
            : visita.efectiva
            ? SigmaColors.success
            : SigmaColors.danger;

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withOpacity(0.10),
                      child: Icon(
                        visita.pendienteOffline
                            ? Icons.cloud_upload_outlined
                            : visita.efectiva
                            ? Icons.check_rounded
                            : Icons.close_rounded,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            visita.clienteNombre,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            visita.pendienteOffline
                                ? 'Pendiente de envío'
                                : visita.efectiva
                                ? 'Visita efectiva'
                                : 'Visita no efectiva',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Detail(
                  label: 'Fecha',
                  value: DateFormat(
                    'dd/MM/yyyy · HH:mm',
                  ).format(visita.fechaInicio),
                ),
                _Detail(label: 'Resultado', value: visita.resultado),
                if (visita.tipoAtencion != null)
                  _Detail(label: 'Atención', value: visita.tipoAtencion!),
                if (visita.duracionMinutos != null)
                  _Detail(
                    label: 'Duración',
                    value: '${visita.duracionMinutos} min',
                  ),
                if (visita.motivo != null)
                  _Detail(label: 'Motivo', value: visita.motivo!),
                if (visita.observaciones != null)
                  _Detail(label: 'Observación', value: visita.observaciones!),
                if (visita.direccion != null)
                  _Detail(label: 'Lugar', value: visita.direccion!),
                if (visita.pedidoCodigo != null || visita.montoPedido != null)
                  _Detail(
                    label: 'Pedido',
                    value: [
                      if (visita.pedidoCodigo != null) visita.pedidoCodigo!,
                      if (visita.montoPedido != null)
                        'Bs ${visita.montoPedido!.toStringAsFixed(2)}',
                    ].join(' · '),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.controller,
    required this.value,
    required this.label,
  });

  final HistorialVisitadorController controller;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(label),
        selected: controller.selectedFilter.value == value,
        onSelected: (_) => controller.setFilter(value),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _DataStatus extends StatelessWidget {
  const _DataStatus({
    required this.offline,
    required this.pending,
    required this.onSync,
  });

  final bool offline;
  final int pending;
  final Future<void> Function()? onSync;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: SigmaColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: SigmaColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              offline
                  ? 'Sin conexión. Mostrando lo guardado en el teléfono.'
                  : '$pending visita${pending == 1 ? '' : 's'} pendiente${pending == 1 ? '' : 's'} de envío.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (onSync != null)
            TextButton(onPressed: onSync, child: const Text('Enviar')),
        ],
      ),
    );
  }
}

class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.visita, required this.onTap});

  final VisitaHistorial visita;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = visita.pendienteOffline
        ? SigmaColors.warning
        : visita.efectiva
        ? SigmaColors.success
        : SigmaColors.danger;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.10),
                child: Icon(
                  visita.pendienteOffline
                      ? Icons.cloud_upload_outlined
                      : visita.efectiva
                      ? Icons.check_rounded
                      : Icons.close_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visita.clienteNombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${DateFormat('HH:mm').format(visita.fechaInicio)} · '
                      '${visita.pendienteOffline ? 'Por enviar' : visita.resultado}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.history_toggle_off_rounded,
              size: 48,
              color: SigmaColors.secondary,
            ),
            const SizedBox(height: 10),
            Text(
              'No hay visitas para mostrar',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
