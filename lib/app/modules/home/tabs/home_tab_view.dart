import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/utils/app_theme.dart';
import 'home_tab_controller.dart';

class HomeTabView extends StatefulWidget {
  const HomeTabView({super.key});

  @override
  State<HomeTabView> createState() => _HomeTabViewState();
}

class _HomeTabViewState extends State<HomeTabView> {
  final controller = Get.put(HomeTabController());
  final mapController = MapController();

  @override
  void initState() {
    super.initState();
    ever(controller.currentPosition, (pos) {
      if (pos != null && mounted) {
        mapController.move(LatLng(pos.latitude, pos.longitude), 17);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pos = controller.currentPosition.value;
      final routePoints = controller.routePoints
          .map((p) => LatLng(p.latitude, p.longitude))
          .where((p) => p.latitude.isFinite && p.longitude.isFinite)
          .toList();

      return Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {},
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                _HeroStatus(controller: controller),
                const SizedBox(height: 14),
                _MapCard(
                  mapController: mapController,
                  pos: pos,
                  routePoints: routePoints,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    SigmaMetricCard(
                      title: 'Puntos enviados',
                      value: '${controller.routePoints.length}',
                      icon: Icons.route,
                      color: SigmaColors.primary,
                    ),
                    const SizedBox(width: 10),
                    SigmaMetricCard(
                      title: 'Precisión',
                      value: controller.accuracyText.value,
                      icon: Icons.gps_fixed,
                      color: SigmaColors.secondary,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _InfoPanel(controller: controller),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: controller.isTracking.value
                            ? null
                            : () => controller.startTracking(),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Iniciar jornada GPS'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: controller.isTracking.value
                            ? () => controller.stopTracking()
                            : null,
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('Detener'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Consejo: mantén el GPS activo y la app abierta para registrar el recorrido en tiempo real.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _HeroStatus extends StatelessWidget {
  const _HeroStatus({required this.controller});
  final HomeTabController controller;

  @override
  Widget build(BuildContext context) {
    final active = controller.isTracking.value;
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
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  active ? Icons.sensors : Icons.location_disabled,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active ? 'Tracking en curso' : 'Tracking detenido',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      active
                          ? 'Registrando puntos GPS hacia MongoDB'
                          : 'Presiona iniciar para comenzar el recorrido',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.86),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: active ? Colors.greenAccent : Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (active ? Colors.greenAccent : Colors.redAccent)
                          .withOpacity(0.7),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroPill(
                label: controller.statusText.value,
                icon: Icons.info_outline,
              ),
              _HeroPill(
                label: controller.isSending.value ? 'Enviando...' : 'Listo',
                icon: Icons.cloud_upload_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label, required this.icon});
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

class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.mapController,
    required this.pos,
    required this.routePoints,
  });
  final MapController mapController;
  final dynamic pos;
  final List<LatLng> routePoints;

  @override
  Widget build(BuildContext context) {
    final center = pos != null
        ? LatLng(pos.latitude, pos.longitude)
        : const LatLng(-17.3895, -66.1568);

    return SigmaCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 330,
          child: Stack(
            children: [
              FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: pos != null ? 18 : 14,
                  minZoom: 3,
                  maxZoom: 22,
                ),
                children: [
                  TileLayer(
                    tileProvider: CancellableNetworkTileProvider(),
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.sigpred.app',
                  ),
                  if (routePoints.length > 1)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: routePoints,
                          color: SigmaColors.primary,
                          strokeWidth: 5,
                        ),
                      ],
                    ),
                  if (pos != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: center,
                          width: 44,
                          height: 44,
                          child: Container(
                            decoration: BoxDecoration(
                              color: SigmaColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: SigmaColors.primary.withOpacity(0.35),
                                  blurRadius: 9,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              Positioned(
                left: 14,
                top: 14,
                child: SigmaPill(
                  label: pos != null ? 'Ubicación actual' : 'Esperando GPS',
                  icon: pos != null ? Icons.gps_fixed : Icons.gps_not_fixed,
                  color: pos != null
                      ? SigmaColors.success
                      : SigmaColors.warning,
                ),
              ),
              if (pos != null)
                Positioned(
                  bottom: 14,
                  right: 14,
                  child: FloatingActionButton.small(
                    heroTag: 'home_center_map',
                    backgroundColor: Colors.white,
                    onPressed: () => mapController.move(center, 20),
                    child: const Icon(
                      Icons.my_location,
                      color: SigmaColors.ink,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.controller});
  final HomeTabController controller;

  @override
  Widget build(BuildContext context) {
    return SigmaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estado operativo',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.place,
            label: 'Última ubicación',
            value: controller.lastLocationText.value,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.gps_fixed,
            label: 'Precisión estimada',
            value: controller.accuracyText.value,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.cloud_done_outlined,
            label: 'Servidor',
            value: controller.isSending.value
                ? 'Enviando ubicación'
                : 'Sincronización lista',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: SigmaColors.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
