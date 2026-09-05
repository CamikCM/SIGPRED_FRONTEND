import 'package:flutter/material.dart';
import '../../../utils/app_theme.dart';
import '../../../data/models/userlastlocation.dart';

class WebLeafletMap extends StatelessWidget {
  const WebLeafletMap({super.key, required this.items});

  final List<UserLastLocation> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE5E7EB),
      alignment: Alignment.center,
      child: const Text(
        'Mapa web disponible al ejecutar en navegador.',
        style: TextStyle(color: SigmaColors.muted, fontWeight: FontWeight.w700),
      ),
    );
  }
}
