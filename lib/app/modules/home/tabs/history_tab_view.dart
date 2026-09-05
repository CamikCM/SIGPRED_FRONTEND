import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/utils/app_theme.dart';
import '../../../data/models/location_results.dart';
import 'history_tab_controller.dart';

class HistoryTabView extends StatefulWidget {
  const HistoryTabView({super.key});

  @override
  State<HistoryTabView> createState() => _HistoryTabViewState();
}

class _HistoryTabViewState extends State<HistoryTabView> {
  late final HistoryTabController controller;
  late final String _controllerTag;

  final MapController mapController = MapController();
  bool _mapReady = false;

  static const LatLng _defaultCenter = LatLng(-17.3895, -66.1568);

  @override
  void initState() {
    super.initState();

    _controllerTag = 'history_${identityHashCode(this)}';
    controller = Get.put(HistoryTabController(), tag: _controllerTag);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await controller.initialize();
      _scheduleFit();
    });
  }

  @override
  void dispose() {
    if (Get.isRegistered<HistoryTabController>(tag: _controllerTag)) {
      Get.delete<HistoryTabController>(tag: _controllerTag, force: true);
    }

    super.dispose();
  }

  List<LocationResult> _validLocations() {
    return controller.userLocations.where((loc) {
      return loc.latitude.isFinite &&
          loc.longitude.isFinite &&
          loc.latitude >= -90 &&
          loc.latitude <= 90 &&
          loc.longitude >= -180 &&
          loc.longitude <= 180 &&
          !(loc.latitude == 0 && loc.longitude == 0);
    }).toList();
  }

  List<LatLng> _validPoints() {
    return _validLocations()
        .map((loc) => LatLng(loc.latitude, loc.longitude))
        .toList();
  }

  void _scheduleFit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady) return;
      _fitMapToLocations();
    });
  }

  void _onMapReady() {
    _mapReady = true;
    _scheduleFit();
  }

  void _fitMapToLocations() {
    if (!_mapReady) return;

    final points = _validPoints();
    if (points.isEmpty) return;

    final uniqueKeys = points
        .map(
          (p) =>
              '${p.latitude.toStringAsFixed(7)},'
              '${p.longitude.toStringAsFixed(7)}',
        )
        .toSet();

    if (points.length == 1 || uniqueKeys.length == 1) {
      mapController.move(points.first, 17);
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);

    mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 42),
        maxZoom: 21,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final validLocations = _validLocations();
      final points = _validPoints();
      final center = points.isNotEmpty ? points.last : _defaultCenter;

      return Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              if (controller.isSupervisor) {
                await controller.loadTrackableUsers();
              }

              await controller.fetchUserLocations();
              _scheduleFit();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                _Header(controller: controller, onDataChanged: _scheduleFit),
                const SizedBox(height: 14),
                Row(
                  children: [
                    SigmaMetricCard(
                      title: 'Puntos',
                      value: controller.pointCountText,
                      icon: Icons.route,
                      color: SigmaColors.primary,
                    ),
                    const SizedBox(width: 10),
                    SigmaMetricCard(
                      title: 'Distancia',
                      value: controller.distanceText,
                      icon: Icons.straighten,
                      color: SigmaColors.secondary,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SigmaMetricCard(
                      title: 'Horario',
                      value: controller.timeRangeText,
                      icon: Icons.schedule,
                      color: SigmaColors.success,
                    ),
                    const SizedBox(width: 10),
                    SigmaMetricCard(
                      title: 'Precisión prom.',
                      value: controller.avgAccuracy <= 0
                          ? '--'
                          : '${controller.avgAccuracy.toStringAsFixed(1)} m',
                      icon: Icons.gps_fixed,
                      color: SigmaColors.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _MapCard(
                  controller: controller,
                  mapController: mapController,
                  center: center,
                  validLocations: validLocations,
                  points: points,
                  onFit: _fitMapToLocations,
                  onMapReady: _onMapReady,
                ),
                const SizedBox(height: 14),
                if (controller.isLoading.value)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (validLocations.isEmpty)
                  _EmptyHistory(
                    isSupervisor: controller.isSupervisor,
                    hasSelectedUser: controller.selectedUserId.value != null,
                  )
                else
                  _Timeline(locations: validLocations),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.onDataChanged});

  final HistoryTabController controller;
  final VoidCallback onDataChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: SigmaGradients.primary,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: SigmaColors.primary.withOpacity(0.25),
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
              const Icon(Icons.timeline, color: Colors.white, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Historial de recorrido',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            controller.isSupervisor
                ? 'Selecciona un visitador y consulta el camino registrado '
                      'por GPS durante su jornada.'
                : 'Consulta el camino registrado por GPS durante la jornada '
                      'del visitador.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.90),
            ),
          ),
          if (controller.isSupervisor) ...[
            const SizedBox(height: 14),
            _VisitadorSelector(
              controller: controller,
              onDataChanged: onDataChanged,
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.dateController,
                  readOnly: true,
                  onTap: () async {
                    await controller.pickDate(context);
                    onDataChanged();
                  },
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Fecha',
                    prefixIcon: const Icon(
                      Icons.date_range,
                      color: Colors.white,
                    ),
                    suffixIcon: const Icon(
                      Icons.expand_more,
                      color: Colors.white,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.16),
                    hintStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.25),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () async {
                  await controller.fetchUserLocations();
                  onDataChanged();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: SigmaColors.primary,
                  minimumSize: const Size(100, 56),
                ),
                icon: const Icon(Icons.search),
                label: const Text('Buscar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VisitadorSelector extends StatelessWidget {
  const _VisitadorSelector({
    required this.controller,
    required this.onDataChanged,
  });

  final HistoryTabController controller;
  final VoidCallback onDataChanged;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoadingUsers.value && controller.availableUsers.isEmpty) {
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Cargando visitadores...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    final enabled = controller.availableUsers.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled
            ? () async {
                final selectedId = await _showVisitadorPicker(
                  context,
                  controller,
                );

                if (selectedId == null) return;

                await controller.selectUser(selectedId);
                onDataChanged();
              }
            : null,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.badge_outlined, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  enabled
                      ? controller.selectedUserLabel
                      : 'Sin visitadores con ubicación',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (enabled) const Icon(Icons.expand_more, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Future<int?> _showVisitadorPicker(
    BuildContext context,
    HistoryTabController controller,
  ) {
    final users = controller.availableUsers.toList();
    final selectedId = controller.selectedUserId.value;

    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: Text(
                  'Seleccionar visitador',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              ...users.map(
                (user) => ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      user.name.trim().isEmpty
                          ? '?'
                          : user.name.trim()[0].toUpperCase(),
                    ),
                  ),
                  title: Text(
                    user.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: user.role.trim().isEmpty
                      ? Text('ID ${user.id}')
                      : Text('${user.role} · ID ${user.id}'),
                  trailing: selectedId == user.id
                      ? const Icon(
                          Icons.check_circle,
                          color: SigmaColors.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(user.id),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.controller,
    required this.mapController,
    required this.center,
    required this.validLocations,
    required this.points,
    required this.onFit,
    required this.onMapReady,
  });

  final HistoryTabController controller;
  final MapController mapController;
  final LatLng center;
  final List<LocationResult> validLocations;
  final List<LatLng> points;
  final VoidCallback onFit;
  final VoidCallback onMapReady;

  @override
  Widget build(BuildContext context) {
    return SigmaCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 390,
          child: Stack(
            children: [
              FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: points.isNotEmpty ? 16 : 13,
                  minZoom: 3,
                  maxZoom: 22,
                  onMapReady: onMapReady,
                ),
                children: [
                  TileLayer(
                    tileProvider: CancellableNetworkTileProvider(),
                    key: ValueKey(controller.currentMap.value),
                    urlTemplate:
                        controller.mapStyles[controller.currentMap.value]!,
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.sigpred.app',
                  ),
                  if (validLocations.length > 1)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: points,
                          color: SigmaColors.primary,
                          strokeWidth: 5,
                        ),
                      ],
                    ),
                  if (validLocations.isNotEmpty)
                    MarkerLayer(
                      markers: validLocations.asMap().entries.map((entry) {
                        final index = entry.key;
                        final loc = entry.value;
                        final isFirst = index == 0;
                        final isLast = index == validLocations.length - 1;

                        return Marker(
                          point: LatLng(loc.latitude, loc.longitude),
                          width: isFirst || isLast ? 36 : 15,
                          height: isFirst || isLast ? 36 : 15,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isLast
                                  ? SigmaColors.primary
                                  : isFirst
                                  ? SigmaColors.success
                                  : SigmaColors.secondary,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.22),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Icon(
                              isLast
                                  ? Icons.flag
                                  : isFirst
                                  ? Icons.play_arrow
                                  : Icons.circle,
                              color: Colors.white,
                              size: isFirst || isLast ? 16 : 5,
                            ),
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
                  label: validLocations.length > 1
                      ? 'Ruta trazada'
                      : 'Último punto',
                  icon: validLocations.length > 1 ? Icons.route : Icons.place,
                  color: validLocations.length > 1
                      ? SigmaColors.primary
                      : SigmaColors.secondary,
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Column(
                  children: [
                    _MapFab(icon: Icons.my_location, onPressed: onFit),
                    const SizedBox(height: 8),
                    _MapFab(
                      icon: Icons.add,
                      onPressed: () {
                        final zoom = math
                            .min(mapController.camera.zoom + 1, 18)
                            .toDouble();

                        mapController.move(mapController.camera.center, zoom);
                      },
                    ),
                    const SizedBox(height: 8),
                    _MapFab(
                      icon: Icons.remove,
                      onPressed: () {
                        final zoom = math
                            .max(mapController.camera.zoom - 1, 3)
                            .toDouble();

                        mapController.move(mapController.camera.center, zoom);
                      },
                    ),
                    const SizedBox(height: 8),
                    _MapFab(
                      icon: Icons.layers,
                      onPressed: () => _showMapStyles(context, controller),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMapStyles(BuildContext context, HistoryTabController controller) {
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

class _MapFab extends StatelessWidget {
  const _MapFab({required this.icon, required this.onPressed});

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

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({
    required this.isSupervisor,
    required this.hasSelectedUser,
  });

  final bool isSupervisor;
  final bool hasSelectedUser;

  @override
  Widget build(BuildContext context) {
    final message = isSupervisor && !hasSelectedUser
        ? 'No hay un visitador disponible para consultar.'
        : 'Elige otra fecha o verifica que existan puntos GPS registrados.';

    return SigmaCard(
      child: Column(
        children: [
          Icon(
            Icons.route_outlined,
            size: 46,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          const Text(
            'Sin recorrido para mostrar',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.locations});

  final List<LocationResult> locations;

  @override
  Widget build(BuildContext context) {
    final shown = locations.reversed.take(8).toList();

    return SigmaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Últimos puntos registrados',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          ...shown.map((loc) {
            final time =
                '${loc.capturedAt.hour.toString().padLeft(2, '0')}:'
                '${loc.capturedAt.minute.toString().padLeft(2, '0')}';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: SigmaColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.place,
                      color: SigmaColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          time,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${loc.latitude.toStringAsFixed(6)}, '
                          '${loc.longitude.toStringAsFixed(6)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (loc.accuracy != null)
                    Text(
                      '${loc.accuracy!.toStringAsFixed(1)} m',
                      style: Theme.of(context).textTheme.labelMedium,
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
