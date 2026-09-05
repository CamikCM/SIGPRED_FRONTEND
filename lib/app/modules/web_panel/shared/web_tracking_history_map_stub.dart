import 'package:flutter/material.dart';

import '../../../data/models/location_results.dart';
import 'web_tracking_history_map.dart';

class WebTrackingHistoryMap extends StatelessWidget {
  const WebTrackingHistoryMap({
    super.key,
    required this.items,
    required this.visitadorName,
    required this.visitPoints,
    this.liveMode = false,
    this.focusTarget,
  });

  final List<LocationResult> items;
  final String visitadorName;
  final List<WebAssignedVisitPoint> visitPoints;
  final bool liveMode;
  final String? focusTarget;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE5E7EB),
      alignment: Alignment.center,
      child: Text(
        items.isEmpty
            ? 'Sin recorrido GPS para esta fecha.'
            : 'Mapa histórico disponible en Flutter Web.',
      ),
    );
  }
}
