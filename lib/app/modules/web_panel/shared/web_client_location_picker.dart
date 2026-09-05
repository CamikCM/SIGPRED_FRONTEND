import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';

import '../../../utils/app_theme.dart';

class WebClientLocationPicker extends StatefulWidget {
  const WebClientLocationPicker({
    super.key,
    required this.latitudeController,
    required this.longitudeController,
  });

  final TextEditingController latitudeController;
  final TextEditingController longitudeController;

  @override
  State<WebClientLocationPicker> createState() =>
      _WebClientLocationPickerState();
}

class _WebClientLocationPickerState extends State<WebClientLocationPicker> {
  final MapController _mapController = MapController();

  // Centro inicial del área de trabajo del proyecto.
  static const LatLng _defaultCenter = LatLng(-16.9970, -65.2450);

  LatLng? _selected;

  @override
  void initState() {
    super.initState();
    _selected = _pointFromControllers();
  }

  LatLng? _pointFromControllers() {
    final lat = _parse(widget.latitudeController.text);
    final lng = _parse(widget.longitudeController.text);

    if (lat == null ||
        lng == null ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      return null;
    }

    return LatLng(lat, lng);
  }

  double? _parse(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    return normalized.isEmpty ? null : double.tryParse(normalized);
  }

  void _selectPoint(LatLng point) {
    setState(() => _selected = point);

    widget.latitudeController.text = point.latitude.toStringAsFixed(6);
    widget.longitudeController.text = point.longitude.toStringAsFixed(6);
  }

  void _clearPoint() {
    setState(() => _selected = null);
    widget.latitudeController.clear();
    widget.longitudeController.clear();
  }

  void _centerSelected() {
    final point = _selected;
    if (point == null) return;
    _mapController.move(point, 17);
  }

  @override
  Widget build(BuildContext context) {
    final point = _selected;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withOpacity(.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: SigmaColors.primary.withOpacity(.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.add_location_alt_outlined,
                    color: SigmaColors.primary,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point == null
                            ? 'Marca el punto de visita'
                            : 'Ubicación seleccionada',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        point == null
                            ? 'Haz clic sobre el mapa exactamente donde se encuentra el cliente.'
                            : 'Puedes hacer clic en otro lugar para corregir la ubicación.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (point != null) ...[
                  IconButton(
                    tooltip: 'Centrar en el punto',
                    onPressed: _centerSelected,
                    icon: const Icon(Icons.my_location_rounded),
                  ),
                  IconButton(
                    tooltip: 'Quitar ubicación',
                    onPressed: _clearPoint,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            height: 360,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: point ?? _defaultCenter,
                initialZoom: point == null ? 14 : 17,
                minZoom: 3,
                maxZoom: 22,
                onTap: (_, selectedPoint) => _selectPoint(selectedPoint),
              ),
              children: [
                TileLayer(
                  tileProvider: CancellableNetworkTileProvider(),
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.sigpred.app',
                ),
                if (point != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 58,
                        height: 58,
                        child: Container(
                          decoration: BoxDecoration(
                            color: SigmaColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.22),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.place_rounded,
                            color: Colors.white,
                            size: 29,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (point == null
                                ? SigmaColors.warning
                                : SigmaColors.success)
                            .withOpacity(.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          (point == null
                                  ? SigmaColors.warning
                                  : SigmaColors.success)
                              .withOpacity(.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        point == null
                            ? Icons.location_off_outlined
                            : Icons.check_circle_outline_rounded,
                        color: point == null
                            ? SigmaColors.warning
                            : SigmaColors.success,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          point == null
                              ? 'Aún no se seleccionó una ubicación.'
                              : 'Ubicación lista para guardar y utilizar en las rutas.',
                          style: const TextStyle(
                            color: SigmaColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (point != null) ...[
                  const SizedBox(height: 8),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'Datos técnicos de ubicación',
                      style: TextStyle(
                        color: SigmaColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _CoordinateValue(
                              label: 'Latitud',
                              value: point.latitude.toStringAsFixed(6),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CoordinateValue(
                              label: 'Longitud',
                              value: point.longitude.toStringAsFixed(6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoordinateValue extends StatelessWidget {
  const _CoordinateValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.gps_fixed_rounded,
            size: 17,
            color: SigmaColors.secondary,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
