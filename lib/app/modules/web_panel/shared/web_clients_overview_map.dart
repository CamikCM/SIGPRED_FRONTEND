import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';

import '../../../utils/app_theme.dart';

class WebClientsOverviewMap extends StatefulWidget {
  const WebClientsOverviewMap({super.key, required this.clients});

  final List<Map<String, dynamic>> clients;

  @override
  State<WebClientsOverviewMap> createState() => _WebClientsOverviewMapState();
}

class _WebClientsOverviewMapState extends State<WebClientsOverviewMap> {
  final MapController _controller = MapController();

  static const LatLng _fallback = LatLng(-16.9970, -65.2450);

  List<_ClientPoint> get _points {
    final result = <_ClientPoint>[];

    for (final client in widget.clients) {
      final lat = _double(client['cliente_lat']);
      final lng = _double(client['cliente_lng']);

      if (!_valid(lat, lng)) continue;

      result.add(
        _ClientPoint(
          point: LatLng(lat!, lng!),
          name: client['cliente_nombre']?.toString() ?? 'Cliente',
          address: client['cliente_dir']?.toString() ?? '',
          active: _int(client['est_id']) == 1,
        ),
      );
    }

    return result;
  }

  @override
  void didUpdateWidget(covariant WebClientsOverviewMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clients != widget.clients) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
  }

  void _fit() {
    final points = _points;
    if (points.isEmpty) {
      _controller.move(_fallback, 13);
      return;
    }

    if (points.length == 1) {
      _controller.move(points.first.point, 16);
      return;
    }

    _controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points.map((e) => e.point).toList()),
        padding: const EdgeInsets.all(42),
        maxZoom: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    final withoutLocation = widget.clients.length - points.length;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(.16),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 11),
            child: Row(
              children: [
                const Icon(Icons.map_outlined, color: SigmaColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Clientes en el mapa',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _MapCount(
                  icon: Icons.location_on_outlined,
                  text: '${points.length} ubicados',
                  color: SigmaColors.success,
                ),
                if (withoutLocation > 0) ...[
                  const SizedBox(width: 8),
                  _MapCount(
                    icon: Icons.location_off_outlined,
                    text: '$withoutLocation sin ubicación',
                    color: SigmaColors.warning,
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: points.isEmpty ? _fallback : points.first.point,
                initialZoom: points.isEmpty ? 13 : 15,
                minZoom: 3,
                maxZoom: 22,
              ),
              children: [
                TileLayer(
                  tileProvider: CancellableNetworkTileProvider(),
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.sigpred.app',
                ),
                MarkerLayer(
                  markers: points
                      .map(
                        (item) => Marker(
                          point: item.point,
                          width: 46,
                          height: 46,
                          child: Tooltip(
                            message: item.address.isEmpty
                                ? item.name
                                : '${item.name}\n${item.address}',
                            child: Container(
                              decoration: BoxDecoration(
                                color: item.active
                                    ? SigmaColors.primary
                                    : SigmaColors.muted,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(.20),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.place_rounded,
                                color: Colors.white,
                                size: 23,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapCount extends StatelessWidget {
  const _MapCount({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientPoint {
  const _ClientPoint({
    required this.point,
    required this.name,
    required this.address,
    required this.active,
  });

  final LatLng point;
  final String name;
  final String address;
  final bool active;
}

double? _double(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.'));
}

int? _int(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool _valid(double? lat, double? lng) {
  if (lat == null || lng == null) return false;
  if (!lat.isFinite || !lng.isFinite) return false;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
  if (lat == 0 && lng == 0) return false;
  return true;
}
