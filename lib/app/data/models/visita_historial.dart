class VisitaHistorial {
  const VisitaHistorial({
    required this.id,
    required this.clienteId,
    required this.clienteNombre,
    required this.fechaInicio,
    required this.efectiva,
    required this.resultado,
    required this.estadoSincronizacion,
    this.fechaFin,
    this.tipoAtencion,
    this.motivo,
    this.observaciones,
    this.latitud,
    this.longitud,
    this.duracionMinutos,
    this.rutaNombre,
    this.zonaNombre,
    this.direccion,
    this.pedidoCodigo,
    this.montoPedido,
    this.pendienteOffline = false,
  });

  final String id;
  final int? clienteId;
  final String clienteNombre;
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final bool efectiva;
  final String resultado;
  final String? tipoAtencion;
  final String? motivo;
  final String? observaciones;
  final double? latitud;
  final double? longitud;
  final int? duracionMinutos;
  final String? rutaNombre;
  final String? zonaNombre;
  final String? direccion;
  final String? pedidoCodigo;
  final double? montoPedido;
  final bool pendienteOffline;
  final String estadoSincronizacion;

  factory VisitaHistorial.fromApi(Map<String, dynamic> json) {
    final cliente = _asMap(json['cliente']);
    final zona = _asMap(cliente?['zona']);
    final jornada = _asMap(json['jornada']);
    final ruta = _asMap(jornada?['ruta']);
    final pedido = _asMap(json['pedido']);

    return VisitaHistorial(
      id: (json['vis_id'] ?? json['id'] ?? '').toString(),
      clienteId: _toInt(json['cliente_id'] ?? cliente?['cliente_id']),
      clienteNombre: _text(
        cliente?['cliente_nombre'] ?? json['cliente_nombre'],
        fallback: 'Cliente sin nombre',
      ),
      fechaInicio: _toDate(json['fecha_inicio']) ?? DateTime.now(),
      fechaFin: _toDate(json['fecha_fin']),
      efectiva: _toBool(json['efectiva']),
      resultado: _text(json['resultado'], fallback: 'Sin resultado'),
      tipoAtencion: _nullableText(json['tipo_atencion']),
      motivo: _nullableText(json['motivo']),
      observaciones: _nullableText(json['observaciones']),
      latitud: _toDouble(json['vis_lat'] ?? json['lat']),
      longitud: _toDouble(json['vis_lng'] ?? json['lng']),
      duracionMinutos: _toInt(json['duracion_minutos']),
      rutaNombre: _nullableText(ruta?['ruta_nombre'] ?? json['ruta_nombre']),
      zonaNombre: _nullableText(zona?['zona_nombre'] ?? json['zona_nombre']),
      direccion: _nullableText(cliente?['cliente_dir'] ?? json['cliente_dir']),
      pedidoCodigo: _nullableText(pedido?['pedido_codigo']),
      montoPedido: _toDouble(pedido?['monto_total']),
      pendienteOffline: false,
      estadoSincronizacion: 'Sincronizada',
    );
  }

  factory VisitaHistorial.fromOffline({
    required Map<String, dynamic> record,
    required Map<String, dynamic> payload,
    String? clienteNombre,
    String? clienteDireccion,
  }) {
    final createdAt = _toDate(record['created_at']);
    final inicio =
        _toDate(payload['fecha_inicio']) ?? createdAt ?? DateTime.now();

    return VisitaHistorial(
      id: 'offline-${record['id'] ?? inicio.millisecondsSinceEpoch}',
      clienteId: _toInt(payload['cliente_id']),
      clienteNombre: _text(
        clienteNombre,
        fallback: 'Cliente #${payload['cliente_id'] ?? '--'}',
      ),
      fechaInicio: inicio,
      fechaFin: _toDate(payload['fecha_fin']),
      efectiva: _toBool(payload['efectiva']),
      resultado: _text(
        payload['resultado'],
        fallback: 'Pendiente de sincronización',
      ),
      tipoAtencion: _nullableText(payload['tipo_atencion']),
      motivo: _nullableText(payload['motivo']),
      observaciones: _nullableText(payload['observaciones']),
      latitud: _toDouble(payload['lat']),
      longitud: _toDouble(payload['lng']),
      direccion: _nullableText(clienteDireccion),
      pedidoCodigo: null,
      montoPedido: _offlinePedidoTotal(payload),
      pendienteOffline: true,
      estadoSincronizacion: 'Pendiente offline',
    );
  }

  bool get tieneCoordenadas => latitud != null && longitud != null;

  static double? _offlinePedidoTotal(Map<String, dynamic> payload) {
    final pedido = _asMap(payload['pedido']);
    final detalles = pedido?['detalles'];
    if (detalles is! List) return null;

    var total = 0.0;
    var tieneDetalle = false;
    for (final item in detalles) {
      if (item is! Map) continue;
      final detalle = Map<String, dynamic>.from(item);
      final cantidad = _toInt(detalle['cantidad']) ?? 0;
      final precio = _toDouble(detalle['precio_unitario']) ?? 0;
      total += cantidad * precio;
      tieneDetalle = true;
    }
    return tieneDetalle ? total : null;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase().trim();
    return text == 'true' ||
        text == '1' ||
        text == 't' ||
        text == 'si' ||
        text == 'sí';
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  }

  static String _text(dynamic value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String? _nullableText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
