import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../utils/app_theme.dart';
import 'historial_visitador_controller.dart';

class CentroSincronizacionView extends StatefulWidget {
  const CentroSincronizacionView({super.key, required this.controller});

  final HistorialVisitadorController controller;

  @override
  State<CentroSincronizacionView> createState() =>
      _CentroSincronizacionViewState();
}

class _CentroSincronizacionViewState extends State<CentroSincronizacionView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.cargarRegistrosOffline();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sincronización offline'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: controller.cargarRegistrosOffline,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        final pendientes = controller.pendientesOffline;
        final sincronizados = controller.sincronizadosRecientes;

        return RefreshIndicator(
          onRefresh: controller.cargarRegistrosOffline,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _OfflineHeader(controller: controller),
              const SizedBox(height: 14),
              _OfflineSummary(controller: controller),
              const SizedBox(height: 16),
              if (pendientes.isNotEmpty) ...[
                _SectionTitle(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Pendientes por enviar',
                  subtitle:
                      '${pendientes.length} registro(s) guardado(s) en el teléfono',
                ),
                const SizedBox(height: 10),
                ...pendientes.map(
                  (record) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OfflineRecordCard(
                      controller: controller,
                      record: record,
                      pending: true,
                    ),
                  ),
                ),
              ] else
                const _NoPendingCard(),
              if (sincronizados.isNotEmpty) ...[
                const SizedBox(height: 18),
                _SectionTitle(
                  icon: Icons.cloud_done_outlined,
                  title: 'Sincronizados recientemente',
                  subtitle: 'Últimos registros enviados correctamente',
                ),
                const SizedBox(height: 10),
                ...sincronizados.map(
                  (record) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OfflineRecordCard(
                      controller: controller,
                      record: record,
                      pending: false,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}

class _OfflineHeader extends StatelessWidget {
  const _OfflineHeader({required this.controller});

  final HistorialVisitadorController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: SigmaGradients.primary,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: SigmaColors.primary.withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sync_rounded, color: Colors.white, size: 31),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Centro de sincronización',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Los datos se guardan en el teléfono cuando no hay conexión y se envían después.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.90),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: SigmaColors.primary,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: controller.pendientesOffline.isEmpty
                  ? null
                  : controller.sincronizarPendientes,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(
                controller.pendientesOffline.isEmpty
                    ? 'No hay pendientes'
                    : 'Sincronizar ${controller.pendientesOffline.length} pendiente(s)',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineSummary extends StatelessWidget {
  const _OfflineSummary({required this.controller});

  final HistorialVisitadorController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            SigmaMetricCard(
              title: 'Visitas',
              value: '${controller.pendientesPorTipo('visita')}',
              icon: Icons.fact_check_outlined,
              color: SigmaColors.warning,
            ),
            const SizedBox(width: 10),
            SigmaMetricCard(
              title: 'GPS',
              value: '${controller.pendientesPorTipo('tracking')}',
              icon: Icons.gps_fixed,
              color: SigmaColors.secondary,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            SigmaMetricCard(
              title: 'Inicios',
              value: '${controller.pendientesPorTipo('jornada_inicio')}',
              icon: Icons.play_circle_outline,
              color: SigmaColors.success,
            ),
            const SizedBox(width: 10),
            SigmaMetricCard(
              title: 'Cierres',
              value: '${controller.pendientesPorTipo('jornada_cierre')}',
              icon: Icons.stop_circle_outlined,
              color: SigmaColors.danger,
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: SigmaColors.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: SigmaColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OfflineRecordCard extends StatelessWidget {
  const _OfflineRecordCard({
    required this.controller,
    required this.record,
    required this.pending,
  });

  final HistorialVisitadorController controller;
  final Map<String, dynamic> record;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final attempts = controller.intentosRegistro(record);
    final error = controller.errorRegistro(record);
    final hasError = pending && (attempts > 0 || error != null);
    final statusColor = pending
        ? hasError
              ? SigmaColors.danger
              : SigmaColors.warning
        : SigmaColors.success;
    final date = controller.fechaRegistro(record);

    return SigmaCard(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            pending
                ? hasError
                      ? Icons.sync_problem
                      : Icons.cloud_off_outlined
                : Icons.cloud_done_outlined,
            color: statusColor,
          ),
        ),
        title: Text(
          controller.tipoRegistro(record),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            controller.detalleRegistro(record),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: _StatusBadge(
          label: pending
              ? hasError
                    ? 'Error'
                    : 'Pendiente'
              : 'Sincronizado',
          color: statusColor,
        ),
        children: [
          const Divider(height: 20),
          _RecordDetail(
            label: 'Creado',
            value: date == null
                ? 'Sin fecha'
                : DateFormat('dd/MM/yyyy HH:mm:ss').format(date),
          ),
          _RecordDetail(label: 'Intentos', value: '$attempts'),
          if (error != null)
            _RecordDetail(label: 'Último error', value: error, danger: true),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RecordDetail extends StatelessWidget {
  const _RecordDetail({
    required this.label,
    required this.value,
    this.danger = false,
  });

  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: danger ? SigmaColors.danger : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoPendingCard extends StatelessWidget {
  const _NoPendingCard();

  @override
  Widget build(BuildContext context) {
    return SigmaCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_done_outlined,
              size: 54,
              color: SigmaColors.success,
            ),
            const SizedBox(height: 10),
            Text(
              'Todo está sincronizado',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              'No hay registros pendientes en el teléfono.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
