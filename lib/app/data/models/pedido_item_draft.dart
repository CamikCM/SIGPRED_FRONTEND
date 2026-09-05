class PedidoItemDraft {
  const PedidoItemDraft({
    required this.productoId,
    required this.productoNombre,
    required this.cantidad,
    required this.precioUnitario,
  });

  final int productoId;
  final String productoNombre;
  final int cantidad;
  final double precioUnitario;

  double get subtotal => cantidad * precioUnitario;

  Map<String, dynamic> toPayload() => {
    'producto_id': productoId,
    'cantidad': cantidad,
    'precio_unitario': precioUnitario,
  };

  Map<String, dynamic> toJson() => {
    'producto_id': productoId,
    'producto_nombre': productoNombre,
    'cantidad': cantidad,
    'precio_unitario': precioUnitario,
  };

  factory PedidoItemDraft.fromJson(Map<String, dynamic> json) {
    final rawId = json['producto_id'];
    final rawCantidad = json['cantidad'];
    final rawPrecio = json['precio_unitario'];

    return PedidoItemDraft(
      productoId: rawId is num
          ? rawId.toInt()
          : int.tryParse(rawId?.toString() ?? '') ?? 0,
      productoNombre: (json['producto_nombre'] ?? json['nombre'] ?? 'Producto')
          .toString(),
      cantidad: rawCantidad is num
          ? rawCantidad.toInt()
          : int.tryParse(rawCantidad?.toString() ?? '') ?? 1,
      precioUnitario: rawPrecio is num
          ? rawPrecio.toDouble()
          : double.tryParse(rawPrecio?.toString() ?? '') ?? 0,
    );
  }
}
