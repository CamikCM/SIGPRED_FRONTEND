// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import '../../../data/models/userlastlocation.dart';

class WebLeafletMap extends StatefulWidget {
  const WebLeafletMap({super.key, required this.items});

  final List<UserLastLocation> items;

  @override
  State<WebLeafletMap> createState() => _WebLeafletMapState();
}

class _WebLeafletMapState extends State<WebLeafletMap> {
  late String viewType;
  static final Set<String> _registeredViewTypes = <String>{};

  @override
  void initState() {
    super.initState();
    _registerMap();
  }

  @override
  void didUpdateWidget(covariant WebLeafletMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_signature(oldWidget.items) != _signature(widget.items)) {
      _registerMap();
      setState(() {});
    }
  }

  String _signature(List<UserLastLocation> items) {
    if (items.isEmpty) return 'empty';
    final first = items.first;
    final last = items.last;
    return '${items.length}_${first.latitude}_${first.longitude}_${last.latitude}_${last.longitude}_${last.updatedAt}';
  }

  void _registerMap() {
    final signature = _signature(
      widget.items,
    ).replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    viewType = 'sigpred_leaflet_map_$signature';

    if (_registeredViewTypes.contains(viewType)) return;

    final htmlContent = _buildHtml(widget.items);

    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.borderRadius = '24px'
        ..srcdoc = htmlContent;
      return iframe;
    });

    _registeredViewTypes.add(viewType);
  }

  String _buildHtml(List<UserLastLocation> items) {
    final validItems = items
        .where(
          (e) =>
              e.latitude.isFinite &&
              e.longitude.isFinite &&
              e.latitude >= -90 &&
              e.latitude <= 90 &&
              e.longitude >= -180 &&
              e.longitude <= 180 &&
              !(e.latitude == 0 && e.longitude == 0),
        )
        .map(
          (e) => {
            'name': e.name,
            'lat': e.latitude,
            'lng': e.longitude,
            'updatedAt': e.updatedAt.toIso8601String(),
            'source': e.source ?? 'mobile',
          },
        )
        .toList();

    final centerLat = validItems.isNotEmpty
        ? validItems.first['lat']
        : -17.3895;
    final centerLng = validItems.isNotEmpty
        ? validItems.first['lng']
        : -66.1568;
    final pointsJson = jsonEncode(validItems);

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
  <style>
    html, body, #map { height: 100%; width: 100%; margin: 0; padding: 0; background: #f3f4f6; font-family: Inter, Arial, sans-serif; }
    .leaflet-control-zoom { border: 0 !important; box-shadow: 0 8px 22px rgba(15,23,42,.16) !important; }
    .leaflet-control-zoom a { color: #111827 !important; border: 0 !important; }
    .sigpred-pin { width: 30px; height: 30px; border-radius: 50% 50% 50% 0; background: #e0007a; transform: rotate(-45deg); box-shadow: 0 8px 20px rgba(224,0,122,.35); border: 3px solid white; }
    .sigpred-pin:after { content: ''; width: 10px; height: 10px; background: white; position: absolute; border-radius: 50%; left: 7px; top: 7px; }
    .sigpred-label { background: white; border: 1px solid #e7eaf2; border-radius: 999px; padding: 7px 11px; box-shadow: 0 8px 22px rgba(15,23,42,.16); color: #101828; font-weight: 800; font-size: 12px; white-space: nowrap; }
    .empty { position: absolute; right: 18px; top: 18px; z-index: 1000; background: white; border-radius: 16px; padding: 14px 16px; color: #667085; font-weight: 700; box-shadow: 0 10px 26px rgba(15,23,42,.12); }
  </style>
</head>
<body>
  <div id="map"></div>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <script>
    const points = $pointsJson;
    const map = L.map('map', { zoomControl: true }).setView([$centerLat, $centerLng], points.length <= 1 ? 15 : 13);

    L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', {
      maxZoom: 20,
      subdomains: 'abcd',
      attribution: '&copy; OpenStreetMap &copy; CARTO'
    }).addTo(map);

    const markerGroup = L.featureGroup().addTo(map);

    if (points.length > 1) {
      const route = points.map(p => [p.lat, p.lng]);
      L.polyline(route, { color: '#e0007a', weight: 5, opacity: 0.88, lineJoin: 'round', dashArray: '12 10' }).addTo(markerGroup);
    }

    points.forEach((p, idx) => {
      const icon = L.divIcon({ className: '', html: '<div class="sigpred-pin"></div>', iconSize: [30, 30], iconAnchor: [15, 30] });
      const marker = L.marker([p.lat, p.lng], { icon }).addTo(markerGroup);
      marker.bindTooltip('<div class="sigpred-label">' + p.name + '</div>', { permanent: true, direction: 'top', offset: [0, -24], className: '' });
      marker.bindPopup('<b>' + p.name + '</b><br>' + p.lat + ', ' + p.lng + '<br>' + (p.updatedAt || '') + '<br>' + (p.source || 'mobile'));
    });

    if (points.length > 1) {
      map.fitBounds(markerGroup.getBounds(), { padding: [40, 40], maxZoom: 16 });
    }

    if (points.length === 0) {
      const empty = document.createElement('div');
      empty.className = 'empty';
      empty.innerText = 'Sin ubicaciones válidas para mostrar';
      document.body.appendChild(empty);
    }

    setTimeout(() => map.invalidateSize(), 300);
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: viewType);
  }
}
