import 'pedido_item_draft.dart';

class VisitaActivaDraft {
  const VisitaActivaDraft({
    required this.localUuid,
    required this.detalleRuta,
    required this.fechaInicio,
    required this.tipoAtencion,
    required this.efectiva,
    required this.resultado,
    required this.motivo,
    required this.observaciones,
    required this.pedidoItems,
    required this.updatedAt,
    this.inicioLat,
    this.visitaId,
    this.visitaLocalUuid,
    this.esRevisita = false,
    this.inicioLng,
    this.fechaEntrega,
    this.firmaBase64,
    this.firmaNombre,
    this.firmaRol,
    this.firmaCapturedAt,
  });

  final String localUuid;
  final Map<String, dynamic> detalleRuta;
  final DateTime fechaInicio;
  final double? inicioLat;
  final double? inicioLng;
  final int? visitaId;
  final String? visitaLocalUuid;
  final bool esRevisita;
  final String tipoAtencion;
  final bool efectiva;
  final String resultado;
  final String motivo;
  final String observaciones;
  final List<PedidoItemDraft> pedidoItems;
  final DateTime? fechaEntrega;
  final String? firmaBase64;
  final String? firmaNombre;
  final String? firmaRol;
  final DateTime? firmaCapturedAt;
  final DateTime updatedAt;

  int? get rutaDetalleId => _toInt(detalleRuta['ruta_det_id']);

  int? get clienteId {
    final cliente = detalleRuta['cliente'];
    if (cliente is Map) {
      return _toInt(cliente['cliente_id']);
    }
    return _toInt(detalleRuta['cliente_id']);
  }

  VisitaActivaDraft copyWith({
    Map<String, dynamic>? detalleRuta,
    DateTime? fechaInicio,
    double? inicioLat,
    double? inicioLng,
    int? visitaId,
    String? visitaLocalUuid,
    bool? esRevisita,
    String? tipoAtencion,
    bool? efectiva,
    String? resultado,
    String? motivo,
    String? observaciones,
    List<PedidoItemDraft>? pedidoItems,
    DateTime? fechaEntrega,
    bool clearFechaEntrega = false,
    String? firmaBase64,
    bool clearFirma = false,
    String? firmaNombre,
    String? firmaRol,
    DateTime? firmaCapturedAt,
    DateTime? updatedAt,
  }) {
    return VisitaActivaDraft(
      localUuid: localUuid,
      detalleRuta: detalleRuta ?? this.detalleRuta,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      inicioLat: inicioLat ?? this.inicioLat,
      inicioLng: inicioLng ?? this.inicioLng,
      visitaId: visitaId ?? this.visitaId,
      visitaLocalUuid: visitaLocalUuid ?? this.visitaLocalUuid,
      esRevisita: esRevisita ?? this.esRevisita,
      tipoAtencion: tipoAtencion ?? this.tipoAtencion,
      efectiva: efectiva ?? this.efectiva,
      resultado: resultado ?? this.resultado,
      motivo: motivo ?? this.motivo,
      observaciones: observaciones ?? this.observaciones,
      pedidoItems: pedidoItems ?? this.pedidoItems,
      fechaEntrega: clearFechaEntrega
          ? null
          : (fechaEntrega ?? this.fechaEntrega),
      firmaBase64: clearFirma ? null : (firmaBase64 ?? this.firmaBase64),
      firmaNombre: clearFirma ? null : (firmaNombre ?? this.firmaNombre),
      firmaRol: clearFirma ? null : (firmaRol ?? this.firmaRol),
      firmaCapturedAt: clearFirma
          ? null
          : (firmaCapturedAt ?? this.firmaCapturedAt),
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'local_uuid': localUuid,
    'detalle_ruta': detalleRuta,
    'fecha_inicio': fechaInicio.toIso8601String(),
    if (inicioLat != null) 'inicio_lat': inicioLat,
    if (inicioLng != null) 'inicio_lng': inicioLng,
    if (visitaId != null) 'visita_id': visitaId,
    if (visitaLocalUuid != null && visitaLocalUuid!.trim().isNotEmpty)
      'visita_local_uuid': visitaLocalUuid,
    'es_revisita': esRevisita,
    'tipo_atencion': tipoAtencion,
    'efectiva': efectiva,
    'resultado': resultado,
    'motivo': motivo,
    'observaciones': observaciones,
    'pedido_items': pedidoItems.map((item) => item.toJson()).toList(),
    if (fechaEntrega != null) 'fecha_entrega': fechaEntrega!.toIso8601String(),
    if (firmaBase64 != null && firmaBase64!.isNotEmpty)
      'firma_base64': firmaBase64,
    if (firmaNombre != null && firmaNombre!.trim().isNotEmpty)
      'firma_nombre': firmaNombre,
    if (firmaRol != null && firmaRol!.trim().isNotEmpty) 'firma_rol': firmaRol,
    if (firmaCapturedAt != null)
      'firma_captured_at': firmaCapturedAt!.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory VisitaActivaDraft.fromJson(Map<String, dynamic> json) {
    final detalleRaw = json['detalle_ruta'];
    final itemsRaw = json['pedido_items'];

    return VisitaActivaDraft(
      localUuid: (json['local_uuid'] ?? '').toString(),
      detalleRuta: detalleRaw is Map
          ? Map<String, dynamic>.from(detalleRaw)
          : <String, dynamic>{},
      fechaInicio:
          DateTime.tryParse(json['fecha_inicio']?.toString() ?? '') ??
          DateTime.now(),
      inicioLat: _toDouble(json['inicio_lat']),
      inicioLng: _toDouble(json['inicio_lng']),
      visitaId: _toInt(json['visita_id']),
      visitaLocalUuid: _nullableText(json['visita_local_uuid']),
      esRevisita: _toBool(json['es_revisita'], fallback: false),
      tipoAtencion: (json['tipo_atencion'] ?? 'Presencial').toString(),
      efectiva: _toBool(json['efectiva'], fallback: true),
      resultado: (json['resultado'] ?? 'Visita realizada').toString(),
      motivo: (json['motivo'] ?? '').toString(),
      observaciones: (json['observaciones'] ?? '').toString(),
      pedidoItems: itemsRaw is List
          ? itemsRaw
                .whereType<Map>()
                .map(
                  (item) =>
                      PedidoItemDraft.fromJson(Map<String, dynamic>.from(item)),
                )
                .where((item) => item.productoId > 0)
                .toList()
          : <PedidoItemDraft>[],
      fechaEntrega: DateTime.tryParse(json['fecha_entrega']?.toString() ?? ''),
      firmaBase64: _nullableText(json['firma_base64']),
      firmaNombre: _nullableText(json['firma_nombre']),
      firmaRol: _nullableText(json['firma_rol']),
      firmaCapturedAt: DateTime.tryParse(
        json['firma_captured_at']?.toString() ?? '',
      ),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
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

  static String? _nullableText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static bool _toBool(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return fallback;
  }
}
