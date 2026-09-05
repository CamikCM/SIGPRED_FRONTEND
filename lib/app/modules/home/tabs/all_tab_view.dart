import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/utils/app_theme.dart';
import 'all_tab_controller.dart';

class AllTabView extends StatefulWidget {
  const AllTabView({super.key});

  @override
  State<AllTabView> createState() => _AllTabViewState();
}

class _AllTabViewState extends State<AllTabView> {
  final controller = Get.put(AllTabController());
  final mapController = MapController();

  static const LatLng _defaultCenter = LatLng(-17.3895, -66.1568);

  List<LatLng> get _points => controller.usersLocations
      .where(
        (u) =>
            u.latitude.isFinite &&
            u.longitude.isFinite &&
            !(u.latitude == 0 && u.longitude == 0),
      )
      .map((u) => LatLng(u.latitude, u.longitude))
      .toList();

  void _fit() {
    final points = _points;
    if (points.isEmpty) return;
    final unique = points
        .map(
          (p) =>
              '${p.latitude.toStringAsFixed(7)},${p.longitude.toStringAsFixed(7)}',
        )
        .toSet();
    if (points.length == 1 || unique.length == 1) {
      mapController.move(points.first, 15);
      return;
    }
    mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(48),
        maxZoom: 21,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final points = _points;
      final center = points.isNotEmpty ? points.first : _defaultCenter;

      return Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: controller.refreshLocations,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: SigmaGradients.dark,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.20),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.groups_2, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Supervisión en campo',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            Text(
                              'Última ubicación registrada por usuarios activos',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          await controller.refreshLocations();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) _fit();
                          });
                        },
                        icon: const Icon(Icons.refresh, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    SigmaMetricCard(
                      title: 'Usuarios',
                      value: '${controller.usersLocations.length}',
                      icon: Icons.people_alt,
                      color: SigmaColors.primary,
                    ),
                    const SizedBox(width: 10),
                    SigmaMetricCard(
                      title: 'Estado',
                      value: controller.isLoading.value
                          ? 'Cargando'
                          : 'Actualizado',
                      icon: Icons.cloud_done,
                      color: SigmaColors.success,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SigmaCard(
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox(
                      height: 420,
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: mapController,
                            options: MapOptions(
                              initialCenter: center,
                              initialZoom: points.isNotEmpty ? 12 : 13,
                              minZoom: 3,
                              maxZoom: 22,
                            ),
                            children: [
                              TileLayer(
                                tileProvider: CancellableNetworkTileProvider(),
                                key: ValueKey(controller.currentMap.value),
                                urlTemplate: controller
                                    .mapStyles[controller.currentMap.value]!,
                                subdomains: const ['a', 'b', 'c', 'd'],
                                userAgentPackageName: 'com.sigpred.app',
                              ),
                              MarkerLayer(
                                markers: controller.usersLocations.map((u) {
                                  return Marker(
                                    point: LatLng(u.latitude, u.longitude),
                                    width: 130,
                                    height: 82,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: SigmaColors.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: SigmaColors.primary
                                                    .withOpacity(0.35),
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.person_pin_circle,
                                            color: Colors.white,
                                            size: 17,
                                          ),
                                        ),
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.14,
                                                ),
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            u.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: SigmaColors.ink,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                          Positioned(
                            left: 14,
                            top: 14,
                            child: SigmaPill(
                              label: 'Últimas ubicaciones',
                              icon: Icons.sensors,
                              color: SigmaColors.primary,
                            ),
                          ),
                          Positioned(
                            top: 14,
                            right: 14,
                            child: Column(
                              children: [
                                _MiniMapButton(
                                  icon: Icons.my_location,
                                  onPressed: _fit,
                                ),
                                const SizedBox(height: 8),
                                _MiniMapButton(
                                  icon: Icons.add,
                                  onPressed: () => mapController.move(
                                    mapController.camera.center,
                                    math
                                        .min(mapController.camera.zoom + 1, 18)
                                        .toDouble(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _MiniMapButton(
                                  icon: Icons.remove,
                                  onPressed: () => mapController.move(
                                    mapController.camera.center,
                                    math
                                        .max(mapController.camera.zoom - 1, 3)
                                        .toDouble(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _MiniMapButton(
                                  icon: Icons.layers,
                                  onPressed: () => _showStyles(context),
                                ),
                              ],
                            ),
                          ),
                          if (controller.isLoading.value)
                            Container(
                              color: Colors.black.withOpacity(0.10),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (controller.usersLocations.isEmpty &&
                    !controller.isLoading.value)
                  const SigmaCard(
                    child: Column(
                      children: [
                        Icon(Icons.location_off_outlined, size: 44),
                        SizedBox(height: 8),
                        Text(
                          'Sin usuarios ubicados',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  )
                else
                  SigmaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Listado operativo',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        ...controller.usersLocations.map(
                          (u) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: SigmaColors.primary.withOpacity(
                                0.12,
                              ),
                              child: const Icon(
                                Icons.person_pin,
                                color: SigmaColors.primary,
                              ),
                            ),
                            title: Text(
                              u.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              '${u.latitude.toStringAsFixed(5)}, ${u.longitude.toStringAsFixed(5)}',
                            ),
                            trailing: u.accuracy == null
                                ? null
                                : Text('${u.accuracy!.toStringAsFixed(1)} m'),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  void _showStyles(BuildContext context) {
    Get.bottomSheet(
      SigmaCard(
        margin: const EdgeInsets.all(12),
        child: Wrap(
          children: controller.mapStyles.keys.map((style) {
            return ListTile(
              leading: const Icon(Icons.map_outlined),
              title: Text(style),
              trailing: controller.currentMap.value == style
                  ? const Icon(Icons.check, color: SigmaColors.primary)
                  : null,
              onTap: () {
                controller.changeMapStyle(style);
                Get.back();
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _MiniMapButton extends StatelessWidget {
  const _MiniMapButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 5,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: SigmaColors.ink),
        ),
      ),
    );
  }
}
