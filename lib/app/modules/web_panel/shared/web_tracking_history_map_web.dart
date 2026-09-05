// ignore: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../../../data/models/location_results.dart';
import 'web_tracking_history_map.dart';

class WebTrackingHistoryMap extends StatefulWidget {
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
  State<WebTrackingHistoryMap> createState() => _WebTrackingHistoryMapState();
}

class _WebTrackingHistoryMapState extends State<WebTrackingHistoryMap> {
  late String viewType;
  static final Set<String> _registeredViewTypes = <String>{};

  @override
  void initState() {
    super.initState();
    _registerMap();
  }

  @override
  void didUpdateWidget(covariant WebTrackingHistoryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_signature(oldWidget) != _signature(widget)) {
      _registerMap();
      setState(() {});
    }
  }

  String _signature(WebTrackingHistoryMap value) {
    final historyPart = value.items.isEmpty
        ? 'empty'
        : '${value.items.length}_${value.items.first.latitude}_${value.items.first.longitude}_${value.items.last.latitude}_${value.items.last.longitude}_${value.items.last.capturedAt.millisecondsSinceEpoch}';
    final visitPart = value.visitPoints
        .map(
          (p) =>
              '${p.order}_${p.latitude}_${p.longitude}_${p.status.name}_'
              '${p.visitTime?.millisecondsSinceEpoch ?? 0}',
        )
        .join('_');
    return '${historyPart}_${visitPart}_${value.visitadorName}_'
        '${value.liveMode}_${value.focusTarget ?? 'overview'}';
  }

  void _registerMap() {
    final signature = _signature(
      widget,
    ).replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    viewType = 'sigpred_history_map_$signature';

    if (_registeredViewTypes.contains(viewType)) return;

    final htmlContent = _buildHtml();

    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.borderRadius = '18px'
        ..srcdoc = htmlContent;
      return iframe;
    });

    _registeredViewTypes.add(viewType);
  }

  String _buildHtml() {
    final history = widget.items
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
            'lat': e.latitude,
            'lng': e.longitude,
            'capturedAt': e.capturedAt.toIso8601String(),
            'accuracy': e.accuracy,
          },
        )
        .toList();

    final visits = widget.visitPoints
        .map(
          (p) => {
            'order': p.order,
            'name': p.name,
            'lat': p.latitude,
            'lng': p.longitude,
            'plannedTime': p.plannedTime,
            'status': p.status.name,
            'visitTime': p.visitTime?.toIso8601String(),
            'result': p.result,
            'clientType': p.clientType,
            'zoneName': p.zoneName,
            'address': p.address,
            'phone': p.phone,
            'reference': p.reference,
            'orderAmount': p.orderAmount,
          },
        )
        .toList();

    final allCoordinates = <Map<String, dynamic>>[...history, ...visits];
    final centerLat = allCoordinates.isNotEmpty
        ? allCoordinates.first['lat']
        : -17.3895;
    final centerLng = allCoordinates.isNotEmpty
        ? allCoordinates.first['lng']
        : -66.1568;

    final historyJson = jsonEncode(history);
    final visitsJson = jsonEncode(visits);
    final nameJson = jsonEncode(widget.visitadorName);
    final liveModeJson = widget.liveMode ? 'true' : 'false';
    final focusTargetJson = jsonEncode(widget.focusTarget ?? '');

    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
<style>
html, body, #map { height:100%; width:100%; margin:0; background:#f3f4f6; font-family:Arial,sans-serif; }
.visit-pin { width:28px; height:28px; border-radius:50% 50% 50% 0; transform:rotate(-45deg); border:3px solid white; box-shadow:0 5px 14px rgba(16,24,40,.28); }
.visit-pin span { display:flex; width:100%; height:100%; align-items:center; justify-content:center; transform:rotate(45deg); color:white; font-size:11px; font-weight:900; }
.route-label { background:white; border:1px solid #e7eaf2; border-radius:999px; padding:5px 9px; box-shadow:0 7px 18px rgba(15,23,42,.13); color:#101828; font-weight:800; font-size:10.5px; white-space:nowrap; }
.route-tools {
  display:flex;
  flex-direction:column;
  align-items:flex-end;
  gap:6px;
}
.route-tools-row {
  display:flex;
  gap:6px;
}
.map-action-button {
  min-width:88px;
  border:1px solid #d0d5dd;
  background:rgba(255,255,255,.96);
  color:#344054;
  border-radius:9px;
  padding:7px 9px;
  font-size:10px;
  font-weight:850;
  box-shadow:0 5px 14px rgba(16,24,40,.13);
  cursor:pointer;
  white-space:nowrap;
}
.map-action-button:hover {
  background:#f8fafc;
  border-color:#b8c0cc;
}
.map-action-button.primary {
  background:#ef007b;
  border-color:#ef007b;
  color:#fff;
}
.map-action-button.icon-only {
  min-width:36px;
  width:36px;
  padding-left:0;
  padding-right:0;
}
.route-tracker-light {
  width:12px;
  height:12px;
  border-radius:50%;
  background:#FACC15;
  border:2px solid #ffffff;
  box-shadow:0 0 7px rgba(250,204,21,.80);
}
.playback-control-strip {
  width:226px;
  box-sizing:border-box;
  display:flex;
  align-items:center;
  gap:7px;
  padding:7px 9px;
  border:1px solid #d0d5dd;
  border-radius:9px;
  background:rgba(255,255,255,.96);
  box-shadow:0 5px 14px rgba(16,24,40,.13);
  color:#344054;
  font-size:10px;
  font-weight:800;
}
.playback-control-strip input[type="range"] {
  flex:1;
  min-width:0;
  accent-color:#ef007b;
  cursor:pointer;
}
.playback-speed-value {
  min-width:24px;
  text-align:right;
  color:#ef007b;
  font-weight:900;
}
.playback-progress {
  width:226px;
  box-sizing:border-box;
  padding:6px 9px;
  border:1px solid #e4e7ec;
  border-radius:9px;
  background:rgba(255,255,255,.94);
  box-shadow:0 4px 12px rgba(16,24,40,.10);
  color:#475467;
  font-size:10px;
  font-weight:800;
  text-align:center;
}
.map-action-button:disabled {
  opacity:.45;
  cursor:not-allowed;
}

.visit-popup { min-width:220px; color:#344054; font-size:11.5px; line-height:1.35; }
.visit-popup-title { font-size:13px; font-weight:900; color:#101828; margin-bottom:4px; }
.visit-popup-status { display:inline-block; border-radius:999px; padding:3px 7px; font-size:10px; font-weight:900; margin:2px 0 8px; }
.visit-popup-row { display:flex; gap:7px; margin:4px 0; }
.visit-popup-label { min-width:72px; color:#667085; font-weight:700; }
.visit-popup-value { color:#344054; font-weight:800; flex:1; }
.visit-popup-note { margin-top:7px; padding-top:7px; border-top:1px solid #eaecf0; color:#667085; font-size:10.5px; }
</style>
</head>
<body>
<div id="map"></div>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script>
const history = $historyJson;
const visits = $visitsJson;
const visitadorName = $nameJson;
const liveMode = $liveModeJson;
const focusTarget = $focusTargetJson;
const map = L.map('map').setView([$centerLat, $centerLng], liveMode ? 16.5 : 14);
L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', {
  maxZoom:20, subdomains:'abcd', attribution:'&copy; OpenStreetMap &copy; CARTO'
}).addTo(map);
const routeGroup = L.featureGroup().addTo(map);
const visitGroup = L.featureGroup().addTo(map);

if (history.length > 1) {
  const routeLatLngs = history.map(p => [p.lat,p.lng]);

  L.polyline(routeLatLngs, {
    color:'#ffffff',
    weight:9,
    opacity:.82,
    lineJoin:'round',
    lineCap:'round'
  }).addTo(routeGroup);

  L.polyline(routeLatLngs, {
    color:'#ef007b',
    weight:4.5,
    opacity:.92,
    lineJoin:'round',
    lineCap:'round'
  }).addTo(routeGroup);
}


// Capa Canvas única para todos los GPS estáticos.
// Evita crear cientos o miles de marcadores/elementos DOM.
const RoutePointsLayer = L.Layer.extend({
  initialize: function(points) {
    this._points = points || [];
  },

  onAdd: function(mapInstance) {
    this._map = mapInstance;
    this._canvas = L.DomUtil.create('canvas', 'leaflet-zoom-animated');
    this._canvas.style.pointerEvents = 'none';
    this._canvas.style.zIndex = '310';

    mapInstance.getPane('overlayPane').appendChild(this._canvas);
    mapInstance.on('moveend zoomend resize viewreset', this._redraw, this);
    this._redraw();
  },

  onRemove: function(mapInstance) {
    mapInstance.off('moveend zoomend resize viewreset', this._redraw, this);
    if (this._canvas && this._canvas.parentNode) {
      this._canvas.parentNode.removeChild(this._canvas);
    }
  },

  _redraw: function() {
    if (!this._map || !this._canvas || this._points.length === 0) return;

    const mapSize = this._map.getSize();
    const origin = this._map.containerPointToLayerPoint([0, 0]);
    L.DomUtil.setPosition(this._canvas, origin);

    const dpr = Math.max(1, window.devicePixelRatio || 1);
    this._canvas.width = Math.round(mapSize.x * dpr);
    this._canvas.height = Math.round(mapSize.y * dpr);
    this._canvas.style.width = mapSize.x + 'px';
    this._canvas.style.height = mapSize.y + 'px';

    const ctx = this._canvas.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, mapSize.x, mapSize.y);

    const zoom = this._map.getZoom();
    const radius = zoom >= 17 ? 1.9 : (zoom >= 15 ? 1.45 : 1.05);

    ctx.beginPath();

    for (let i = 0; i < this._points.length; i++) {
      const point = this._points[i];
      const pixel = this._map.latLngToContainerPoint([point.lat, point.lng]);

      if (
        pixel.x < -6 ||
        pixel.y < -6 ||
        pixel.x > mapSize.x + 6 ||
        pixel.y > mapSize.y + 6
      ) {
        continue;
      }

      ctx.moveTo(pixel.x + radius, pixel.y);
      ctx.arc(pixel.x, pixel.y, radius, 0, Math.PI * 2);
    }

    ctx.fillStyle = 'rgba(71,84,103,.40)';
    ctx.fill();
  }
});

if (history.length > 0) {
  new RoutePointsLayer(history).addTo(map);
}

function addGpsEndpoint(point, kind) {
  const start = kind === 'start';
  const color = start ? '#0EA5E9' : '#7C3AED';
  const label = start
    ? 'Inicio del recorrido'
    : (liveMode ? 'Ubicación actual' : 'Fin / última ubicación registrada');

  const marker = L.circleMarker([point.lat, point.lng], {
    radius: kind === 'end' && liveMode ? 10 : 8,
    color:'#fff',
    weight: kind === 'end' && liveMode ? 4 : 3,
    fillColor:color,
    fillOpacity:1
  }).addTo(routeGroup);

  const when = new Date(point.capturedAt);
  marker.bindPopup('<b>'+visitadorName+'</b><br>'+
    label+'<br>'+
    when.toLocaleString()+'<br>'+
    Number(point.lat).toFixed(6)+', '+Number(point.lng).toFixed(6)+
    (point.accuracy==null?'':'<br>Precisión: '+Number(point.accuracy).toFixed(1)+' m'));

  if (kind === 'end' && liveMode) {
    marker.bindTooltip(
      '<div class="route-label">EN VIVO · '+visitadorName+'</div>',
      {
        permanent:true,
        direction:'top',
        offset:[0,-12],
        className:''
      }
    );
  }
}

if (history.length > 0) {
  addGpsEndpoint(history[0], 'start');
  if (history.length > 1) {
    addGpsEndpoint(history[history.length - 1], 'end');
  }
}

function visitVisual(status) {
  if (status === 'completed') {
    return {
      color:'#12B76A',
      label:'Realizada · con pedido'
    };
  }
  if (status === 'ineffective') {
    return {
      color:'#F04438',
      label:'No efectiva · sin pedido'
    };
  }
  return {
    color:'#F79009',
    label:'Pendiente'
  };
}

function safeText(value) {
  if (value === null || value === undefined) return '';
  return String(value)
    .replaceAll('&','&amp;')
    .replaceAll('<','&lt;')
    .replaceAll('>','&gt;')
    .replaceAll('"','&quot;')
    .replaceAll("'","&#039;");
}

function popupRow(label, value) {
  if (value === null || value === undefined || String(value).trim() === '') {
    return '';
  }
  return '<div class="visit-popup-row">'+
    '<div class="visit-popup-label">'+safeText(label)+'</div>'+
    '<div class="visit-popup-value">'+safeText(value)+'</div>'+
    '</div>';
}

function formatMoney(value) {
  if (value === null || value === undefined || value === '') return '';
  const number = Number(value);
  if (!Number.isFinite(number)) return '';
  return 'Bs '+number.toLocaleString('es-BO', {
    minimumFractionDigits:2,
    maximumFractionDigits:2
  });
}

const visitMarkers = {};

visits.forEach(v => {
  const visual = visitVisual(v.status);
  const icon = L.divIcon({
    className:'',
    html:'<div class="visit-pin" style="background:'+visual.color+'"><span>'+
      v.order+'</span></div>',
    iconSize:[32,32],
    iconAnchor:[15,30]
  });

  const marker = L.marker([v.lat,v.lng], {icon}).addTo(visitGroup);

  let popup = '<div class="visit-popup">'+
    '<div class="visit-popup-title">'+
      safeText(v.order+'. '+v.name)+
    '</div>'+
    '<div class="visit-popup-status" style="background:'+visual.color+
      '18;color:'+visual.color+'">'+safeText(visual.label)+'</div>';

  popup += popupRow('Tipo', v.clientType);
  popup += popupRow('Zona', v.zoneName);
  popup += popupRow('Dirección', v.address);
  popup += popupRow('Teléfono', v.phone);
  popup += popupRow('Referencia', v.reference);
  popup += popupRow('Planificada', v.plannedTime);

  if (v.visitTime) {
    popup += popupRow(
      'Registrada',
      new Date(v.visitTime).toLocaleString()
    );
  }

  if (v.orderAmount !== null && v.orderAmount !== undefined) {
    popup += popupRow('Venta', formatMoney(v.orderAmount));
  }

  if (v.result) {
    popup += '<div class="visit-popup-note"><b>Resultado:</b> '+
      safeText(v.result)+'</div>';
  } else if (v.status === 'pending') {
    popup += '<div class="visit-popup-note">'+
      'Todavía no existe una visita registrada para este punto.'+
      '</div>';
  }

  popup += '</div>';

  visitMarkers[String(v.order)] = marker;

  marker.bindPopup(popup, {maxWidth:320});
  marker.bindTooltip(
    '<div class="route-label">'+v.order+'. '+safeText(v.name)+
    ' · '+visual.label+'</div>',
    {
      direction:'top',
      offset:[0,-25],
      className:''
    }
  );

  marker.on('click', () => {
    map.flyTo(
      [v.lat, v.lng],
      Math.max(map.getZoom(), 17),
      {animate:true, duration:.35}
    );
  });
});

if (routeGroup.getLayers().length > 0) {
  map.fitBounds(routeGroup.getBounds(), {
    padding:[48,48],
    maxZoom:17
  });
} else if (visitGroup.getLayers().length > 0) {
  map.fitBounds(visitGroup.getBounds(), {
    padding:[48,48],
    maxZoom:16
  });
}

function focusStart() {
  if (history.length === 0) return;
  map.setView([history[0].lat, history[0].lng], 18);
}

function focusEnd() {
  if (history.length === 0) return;
  const last = history[history.length - 1];
  map.setView([last.lat, last.lng], 18);
}


let playbackMarker = null;
let playbackTimer = null;
let playbackIndex = 0;
let playbackRunning = false;
let playbackCompleted = false;
let playbackSpeed = 5;

let playButton = null;
let pauseButton = null;
let resetPlaybackButton = null;
let speedInput = null;
let speedValue = null;
let progressLabel = null;

const BASE_STEP_MS = 120;

function playbackStepDelay() {
  return Math.max(16, Math.round(BASE_STEP_MS / playbackSpeed));
}

function ensurePlaybackMarker() {
  if (liveMode || history.length === 0) return;

  if (!playbackMarker) {
    const icon = L.divIcon({
      className:'',
      html:'<div class="route-tracker-light"></div>',
      iconSize:[16,16],
      iconAnchor:[8,8]
    });

    playbackMarker = L.marker(
      [history[0].lat, history[0].lng],
      {
        icon,
        zIndexOffset:2200,
        interactive:false
      }
    ).addTo(map);
  }
}

function updatePlaybackUi() {
  if (speedValue) {
    speedValue.textContent = playbackSpeed + 'x';
  }

  if (progressLabel) {
    if (history.length === 0) {
      progressLabel.textContent =
        'No existen puntos de recorrido para visualizar.';
    } else if (history.length === 1) {
      progressLabel.textContent = 'Punto 1 de 1 · sin recorrido para reproducir';
    } else if (playbackCompleted) {
      progressLabel.textContent =
        'Recorrido completado · ' + history.length +
        ' de ' + history.length + ' puntos';
    } else {
      progressLabel.textContent =
        'Punto ' + (playbackIndex + 1) +
        ' de ' + history.length;
    }
  }

  if (playButton) {
    playButton.disabled =
      history.length < 2 || playbackRunning;
  }

  if (pauseButton) {
    pauseButton.disabled =
      history.length < 2 || !playbackRunning;
  }

  if (resetPlaybackButton) {
    resetPlaybackButton.disabled = history.length === 0;
  }
}

function clearPlaybackTimer() {
  if (playbackTimer) {
    clearTimeout(playbackTimer);
    playbackTimer = null;
  }
}

function pausePlayback() {
  clearPlaybackTimer();
  playbackRunning = false;
  updatePlaybackUi();
}

function resetPlayback() {
  pausePlayback();
  playbackIndex = 0;
  playbackCompleted = false;

  ensurePlaybackMarker();

  if (playbackMarker && history.length > 0) {
    const first = [history[0].lat, history[0].lng];
    playbackMarker.setLatLng(first);

    if (!map.getBounds().contains(first)) {
      map.panTo(first, {animate:true, duration:.20});
    }
  }

  updatePlaybackUi();
}

function playbackTick() {
  if (!playbackRunning || history.length < 2) return;

  if (playbackIndex >= history.length - 1) {
    playbackRunning = false;
    playbackCompleted = true;
    clearPlaybackTimer();
    updatePlaybackUi();
    return;
  }

  playbackIndex += 1;

  const point = history[playbackIndex];
  const latlng = L.latLng(point.lat, point.lng);

  ensurePlaybackMarker();

  if (playbackMarker) {
    playbackMarker.setLatLng(latlng);
  }

  // No se cambia el zoom. Solo se recentra suavemente si la luz sale
  // del área visible útil.
  const safeBounds = map.getBounds().pad(-0.16);
  if (!safeBounds.contains(latlng)) {
    map.panTo(latlng, {
      animate:true,
      duration:.18
    });
  }

  if (playbackIndex >= history.length - 1) {
    playbackRunning = false;
    playbackCompleted = true;
    clearPlaybackTimer();
    updatePlaybackUi();
    return;
  }

  updatePlaybackUi();
  playbackTimer = setTimeout(playbackTick, playbackStepDelay());
}

function startPlayback() {
  if (liveMode || history.length < 2) {
    updatePlaybackUi();
    return;
  }

  ensurePlaybackMarker();

  if (playbackCompleted || playbackIndex >= history.length - 1) {
    playbackIndex = 0;
    playbackCompleted = false;

    if (playbackMarker) {
      playbackMarker.setLatLng([history[0].lat, history[0].lng]);
    }
  }

  if (playbackRunning) return;

  playbackRunning = true;
  updatePlaybackUi();
  clearPlaybackTimer();
  playbackTimer = setTimeout(playbackTick, playbackStepDelay());
}

function changePlaybackSpeed(value) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return;

  playbackSpeed = Math.max(1, Math.min(10, Math.round(parsed)));

  // No reinicia ni cambia playbackIndex. El nuevo valor se aplica
  // al siguiente paso del recorrido.
  if (playbackRunning) {
    clearPlaybackTimer();
    playbackTimer = setTimeout(playbackTick, playbackStepDelay());
  }

  updatePlaybackUi();
}

// Estado inicial: una sola luz en el primer GPS y reproducción detenida.
if (!liveMode && history.length > 0) {
  ensurePlaybackMarker();
}

const FocusControl = L.Control.extend({
  options: { position: 'topright' },
  onAdd: function() {
    const box = L.DomUtil.create('div', 'route-tools');
    L.DomEvent.disableClickPropagation(box);
    L.DomEvent.disableScrollPropagation(box);

    function makeButton(parent, label, titleText, className, handler) {
      const button = L.DomUtil.create(
        'button',
        'map-action-button '+(className || ''),
        parent
      );
      button.type = 'button';
      button.innerHTML = label;
      button.title = titleText;
      L.DomEvent.on(button, 'click', handler);
      return button;
    }

    const navigationRow = L.DomUtil.create('div', 'route-tools-row', box);

    makeButton(
      navigationRow,
      '▣ Recorrido',
      'Ver recorrido GPS completo',
      '',
      () => {
        if (routeGroup.getLayers().length > 0) {
          map.fitBounds(routeGroup.getBounds(), {
            padding:[48,48],
            maxZoom:17
          });
        }
      }
    );

    if (visitGroup.getLayers().length > 0) {
      makeButton(
        navigationRow,
        '● Visitas',
        'Ver todos los puntos de visita',
        '',
        () => {
          map.fitBounds(visitGroup.getBounds(), {
            padding:[48,48],
            maxZoom:16
          });
        }
      );
    }

    if (liveMode) {
      const liveRow = L.DomUtil.create('div', 'route-tools-row', box);
      makeButton(
        liveRow,
        '⌖ Centrar visitador',
        'Acercar al último GPS recibido',
        'primary',
        focusEnd
      );
    } else if (history.length > 0) {
      const endpointsRow = L.DomUtil.create(
        'div',
        'route-tools-row',
        box
      );

      makeButton(
        endpointsRow,
        '▶ Inicio',
        'Ver punto de inicio',
        '',
        focusStart
      );

      makeButton(
        endpointsRow,
        '⚑ Fin',
        'Ver última ubicación del recorrido',
        '',
        focusEnd
      );

      const playbackRow = L.DomUtil.create(
        'div',
        'route-tools-row',
        box
      );

      playButton = makeButton(
        playbackRow,
        '▶ Reproducir',
        'Iniciar o continuar el recorrido punto por punto',
        'primary',
        startPlayback
      );

      pauseButton = makeButton(
        playbackRow,
        '⏸ Pausar',
        'Pausar conservando el punto actual',
        '',
        pausePlayback
      );

      const resetRow = L.DomUtil.create(
        'div',
        'route-tools-row',
        box
      );

      resetPlaybackButton = makeButton(
        resetRow,
        '↻ Reiniciar',
        'Volver al primer punto del recorrido',
        '',
        resetPlayback
      );

      const speedStrip = L.DomUtil.create(
        'div',
        'playback-control-strip',
        box
      );

      const speedTitle = L.DomUtil.create('span', '', speedStrip);
      speedTitle.textContent = 'Velocidad';

      speedInput = L.DomUtil.create('input', '', speedStrip);
      speedInput.type = 'range';
      speedInput.min = '1';
      speedInput.max = '10';
      speedInput.step = '1';
      speedInput.value = String(playbackSpeed);
      speedInput.title = 'Velocidad de reproducción: 1x a 10x';

      speedValue = L.DomUtil.create(
        'span',
        'playback-speed-value',
        speedStrip
      );

      L.DomEvent.on(speedInput, 'input', (event) => {
        changePlaybackSpeed(event.target.value);
      });

      progressLabel = L.DomUtil.create(
        'div',
        'playback-progress',
        box
      );

      updatePlaybackUi();
    }

    return box;
  }
});

if (history.length > 0) {
  map.addControl(new FocusControl());
}

if (focusTarget) {
  if (focusTarget.startsWith('start')) {
    focusStart();
  } else if (focusTarget.startsWith('end')) {
    focusEnd();
  } else if (focusTarget.startsWith('visit_')) {
    const parts = focusTarget.split('_');
    const order = parts.length > 1 ? parts[1] : '';
    const marker = visitMarkers[order];

    if (marker) {
      const target = marker.getLatLng();
      map.flyTo(target, 18, {
        animate:true,
        duration:.35
      });
      setTimeout(() => marker.openPopup(), 260);
    }
  }
}

setTimeout(() => map.invalidateSize(), 250);
</script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(key: ValueKey(viewType), viewType: viewType);
  }
}
