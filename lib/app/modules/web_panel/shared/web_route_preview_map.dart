import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';

import '../../../utils/app_theme.dart';

class WebRoutePreviewMap extends StatefulWidget {
  const WebRoutePreviewMap({super.key, required this.clients});

  final List<Map<String, dynamic>> clients;

  @override
  State<WebRoutePreviewMap> createState() => _WebRoutePreviewMapState();
}

class _WebRoutePreviewMapState extends State<WebRoutePreviewMap> {
  final MapController _mapController = MapController();
  static const _fallback = LatLng(-16.9970, -65.2450);

  List<_RouteClientPoint> get _points {
    final result = <_RouteClientPoint>[];

    for (final client in widget.clients) {
      final lat = _double(client['cliente_lat']);
      final lng = _double(client['cliente_lng']);
      if (!_valid(lat, lng)) continue;

      result.add(
        _RouteClientPoint(
          point: LatLng(lat!, lng!),
          name: client['cliente_nombre']?.toString() ?? 'Cliente',
          type: _clientType(client),
        ),
      );
    }

    return result;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
  }

  @override
  void didUpdateWidget(covariant WebRoutePreviewMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
  }

  void _fit() {
    final points = _points;

    try {
      if (points.isEmpty) {
        _mapController.move(_fallback, 13);
        return;
      }

      if (points.length == 1) {
        _mapController.move(points.first.point, 16);
        return;
      }

      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(
            points.map((item) => item.point).toList(),
          ),
          padding: const EdgeInsets.all(36),
          maxZoom: 16,
        ),
      );
    } catch (_) {
      // Puede ocurrir mientras el mapa termina de montar durante
      // un cambio rápido de selección. El siguiente frame lo ajustará.
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    final missing = widget.clients.length - points.length;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(.15),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: SigmaColors.primary,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Ubicación de los puntos',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  _summary(points.length, missing),
                  style: TextStyle(
                    color: missing == 0
                        ? SigmaColors.success
                        : SigmaColors.warning,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
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
                          width: 44,
                          height: 52,
                          alignment: Alignment.topCenter,
                          child: Tooltip(
                            message: item.type.isEmpty
                                ? item.name
                                : '${item.name}\n${item.type}',
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: SigmaColors.primary,
                              size: 42,
                              shadows: [
                                Shadow(color: Color(0x45000000), blurRadius: 5),
                              ],
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

  String _summary(int located, int missing) {
    if (missing == 0) return '$located punto(s)';
    if (located == 0) return '$missing sin ubicación';
    return '$located ubicados · $missing sin ubicación';
  }

  String _clientType(Map<String, dynamic> client) {
    final type = client['tipo_cliente'];
    if (type is Map) {
      return type['tc_nombre']?.toString() ?? '';
    }
    return '';
  }
}

class _RouteClientPoint {
  const _RouteClientPoint({
    required this.point,
    required this.name,
    required this.type,
  });

  final LatLng point;
  final String name;
  final String type;
}

double? _double(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.'));
}

bool _valid(double? lat, double? lng) {
  if (lat == null || lng == null) return false;
  if (!lat.isFinite || !lng.isFinite) return false;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
  if (lat == 0 && lng == 0) return false;
  return true;
}
