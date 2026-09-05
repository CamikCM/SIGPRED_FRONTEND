import 'package:flutter/material.dart';

import '../../../data/providers/web_api_provider.dart';

import '../../../routes/app_routes.dart';
import '../../../utils/app_theme.dart';
import '../layout/web_panel_shell.dart';

class WebConfiguracionView extends StatelessWidget {
  const WebConfiguracionView({
    super.key,
    this.activeRoute = Routes.webAdminConfiguracion,
    this.title = 'Configuración',
    this.subtitle = 'Parámetros generales del sistema SIGPRED.',
  });

  final String activeRoute;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    const items = <_ConfigItem>[
      _ConfigItem(
        icon: Icons.apartment_outlined,
        title: 'Perfil institucional',
        subtitle: 'Nombre del sistema, identidad y descripción institucional.',
      ),
      _ConfigItem(
        icon: Icons.admin_panel_settings_outlined,
        title: 'Roles y permisos',
        subtitle: 'Consulta la organización de accesos y responsabilidades.',
      ),
      _ConfigItem(
        icon: Icons.tune_rounded,
        title: 'Parámetros operativos',
        subtitle:
            'Estados, tipos de cliente y catálogos utilizados por SIGPRED.',
      ),
      _ConfigItem(
        icon: Icons.hub_outlined,
        title: 'Integraciones del sistema',
        subtitle:
            'Servicios conectados utilizados por la arquitectura de SIGPRED.',
      ),
    ];

    return WebPanelShell(
      title: title,
      subtitle: subtitle,
      activeRoute: activeRoute,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SigmaColors.primary.withOpacity(.055),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: SigmaColors.primary.withOpacity(.10)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: SigmaColors.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Esta sección resume la configuración institucional y técnica. '
                    'Las operaciones que modifican datos se mantienen en sus módulos correspondientes.',
                    style: TextStyle(
                      color: SigmaColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 980 ? 2 : 1;
              final width = columns == 2
                  ? (constraints.maxWidth - 14) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: items
                    .map(
                      (item) => SizedBox(
                        width: width,
                        child: _ConfigCard(item: item),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          if (activeRoute == Routes.webAdminConfiguracion) ...[
            const SizedBox(height: 18),
            const _ProductAvailabilityPanel(),
          ],
        ],
      ),
    );
  }
}

class _ConfigCard extends StatelessWidget {
  const _ConfigCard({required this.item});

  final _ConfigItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7EAF0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101828).withOpacity(.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: SigmaColors.primary.withOpacity(.085),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: SigmaColors.primary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: SigmaColors.ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    color: SigmaColors.muted,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Text(
              'Información',
              style: TextStyle(
                color: SigmaColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigItem {
  const _ConfigItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class _ProductAvailabilityPanel extends StatefulWidget {
  const _ProductAvailabilityPanel();

  @override
  State<_ProductAvailabilityPanel> createState() =>
      _ProductAvailabilityPanelState();
}

class _ProductAvailabilityPanelState extends State<_ProductAvailabilityPanel> {
  final WebApiProvider _provider = WebApiProvider();
  late Future<List<Map<String, dynamic>>> _future;
  bool _saving = false;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final data = await _provider.getMap('/productos-disponibilidad');
    final raw = data['productos'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  int? _available(Map<String, dynamic> product) {
    final value = product['cantidad_disponible'];
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  double _price(Map<String, dynamic> product) {
    final value = product['precio_referencial'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _text(dynamic value, {String fallback = '—'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> products) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return products;
    return products.where((product) {
      final haystack = [
        product['producto_codigo'],
        product['producto_nombre'],
        product['producto_presentacion'],
      ].map((value) => value?.toString().toLowerCase() ?? '').join(' ');
      return haystack.contains(query);
    }).toList();
  }

  Future<void> _editProduct(Map<String, dynamic> product) async {
    var codeValue = _text(product['producto_codigo'], fallback: '');
    var nameValue = _text(product['producto_nombre'], fallback: '');
    var presentationValue = _text(
      product['producto_presentacion'],
      fallback: '',
    );
    var priceValue = _price(product).toStringAsFixed(2);
    var availabilityValue = _available(product)?.toString() ?? '0';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        String? nameError;
        String? priceError;
        String? availabilityError;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void submit() {
              final name = nameValue.trim();
              final price = double.tryParse(
                priceValue.trim().replaceAll(',', '.'),
              );
              final availability = int.tryParse(availabilityValue.trim());

              nameError = name.isEmpty
                  ? 'Ingresa el nombre del producto.'
                  : null;
              priceError = price == null || price <= 0
                  ? 'Ingresa un precio mayor a 0.'
                  : null;
              availabilityError = availability == null || availability < 0
                  ? 'Ingresa una cantidad válida.'
                  : null;

              if (nameError != null ||
                  priceError != null ||
                  availabilityError != null) {
                setDialogState(() {});
                return;
              }

              Navigator.of(dialogContext).pop({
                'producto_codigo': codeValue.trim(),
                'producto_nombre': name,
                'producto_presentacion': presentationValue.trim(),
                'precio_referencial': price,
                'cantidad_disponible': availability,
              });
            }

            Widget field({
              required String initialValue,
              required String label,
              required ValueChanged<String> onChanged,
              String? helper,
              String? error,
              TextInputType? keyboardType,
            }) {
              return SizedBox(
                width: 270,
                child: TextFormField(
                  initialValue: initialValue,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(
                    labelText: label,
                    helperText: helper,
                    errorText: error,
                  ),
                  onChanged: onChanged,
                  onFieldSubmitted: (_) => submit(),
                ),
              );
            }

            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
              contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              title: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: SigmaColors.primary.withOpacity(.09),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: SigmaColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Editar producto'),
                        SizedBox(height: 3),
                        Text(
                          'Catálogo y disponibilidad para pedidos',
                          style: TextStyle(
                            fontSize: 12,
                            color: SigmaColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 590,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE7EAF0)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 19,
                              color: SigmaColors.primary,
                            ),
                            SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'El precio se administra desde este módulo. En la aplicación móvil del Visitador se muestra como dato de solo lectura.',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          field(
                            initialValue: codeValue,
                            label: 'Código',
                            helper: 'Identificador interno',
                            onChanged: (value) => codeValue = value,
                          ),
                          field(
                            initialValue: nameValue,
                            label: 'Nombre del producto',
                            error: nameError,
                            onChanged: (value) => nameValue = value,
                          ),
                          field(
                            initialValue: presentationValue,
                            label: 'Presentación',
                            helper: 'Ej.: Caja x 20',
                            onChanged: (value) => presentationValue = value,
                          ),
                          field(
                            initialValue: priceValue,
                            label: 'Precio referencial (Bs)',
                            error: priceError,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (value) => priceValue = value,
                          ),
                          field(
                            initialValue: availabilityValue,
                            label: 'Disponibilidad',
                            helper: 'Unidades disponibles para pedidos',
                            error: availabilityError,
                            keyboardType: TextInputType.number,
                            onChanged: (value) => availabilityValue = value,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: submit,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Guardar cambios'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await _provider.put('/productos/${product['producto_id']}', result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result['producto_nombre']} se actualiza correctamente.',
          ),
        ),
      );
      setState(() => _future = _load());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo guardar el producto. ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _metric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7EAF0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: SigmaColors.primary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              color: SigmaColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: SigmaColors.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopHeader() {
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w900,
      color: SigmaColors.muted,
      letterSpacing: .35,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          SizedBox(width: 105, child: Text('CÓDIGO', style: style)),
          SizedBox(width: 14),
          Expanded(flex: 3, child: Text('PRODUCTO', style: style)),
          SizedBox(width: 14),
          Expanded(flex: 2, child: Text('PRESENTACIÓN', style: style)),
          SizedBox(width: 14),
          SizedBox(width: 115, child: Text('PRECIO', style: style)),
          SizedBox(width: 14),
          SizedBox(width: 135, child: Text('DISPONIBILIDAD', style: style)),
          SizedBox(width: 14),
          SizedBox(width: 148, child: Text('ACCIÓN', style: style)),
        ],
      ),
    );
  }

  Widget _desktopRow(Map<String, dynamic> product) {
    final available = _available(product);
    final price = _price(product);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7EAF0)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 105,
            child: Text(
              _text(product['producto_codigo']),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: SigmaColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 3,
            child: Text(
              _text(product['producto_nombre'], fallback: 'Producto'),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: SigmaColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: Text(
              _text(
                product['producto_presentacion'],
                fallback: 'Sin presentación',
              ),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: SigmaColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 115,
            child: Text(
              'Bs ${price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: SigmaColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 135,
            child: Text(
              available == null ? 'Por configurar' : '$available unidades',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: available == null
                    ? SigmaColors.warning
                    : available > 0
                    ? SigmaColors.success
                    : SigmaColors.danger,
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 148,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: _saving ? null : () => _editProduct(product),
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Editar producto'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactCard(Map<String, dynamic> product) {
    final available = _available(product);
    final price = _price(product);
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE7EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _text(product['producto_nombre'], fallback: 'Producto'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: SigmaColors.ink,
                  ),
                ),
              ),
              Text(
                available == null ? 'Por configurar' : '$available u.',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: available == null
                      ? SigmaColors.warning
                      : available > 0
                      ? SigmaColors.success
                      : SigmaColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_text(product['producto_codigo'], fallback: 'Sin código')} · ${_text(product['producto_presentacion'], fallback: 'Sin presentación')}',
            style: const TextStyle(
              color: SigmaColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Bs ${price.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: SigmaColors.ink,
            ),
          ),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _saving ? null : () => _editProduct(product),
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Editar producto'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7EAF0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101828).withOpacity(.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: SigmaColors.primary.withOpacity(.085),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: SigmaColors.primary,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Productos y disponibilidad para pedidos',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: SigmaColors.ink,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Administra código, nombre, presentación, precio y unidades disponibles del catálogo operativo.',
                      style: TextStyle(
                        color: SigmaColors.muted,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualizar lista',
                onPressed: _saving
                    ? null
                    : () => setState(() {
                        _future = _load();
                      }),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFAEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: Color(0xFFB54708),
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Los pedidos aceptados descuentan la disponibilidad de forma automática. El precio se define únicamente desde Administración y el Visitador lo utiliza como dato de solo lectura.',
                    style: TextStyle(fontWeight: FontWeight.w700, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'No se pudo cargar. Intenta nuevamente.',
                    style: const TextStyle(color: SigmaColors.danger),
                  ),
                );
              }

              final products = snapshot.data ?? <Map<String, dynamic>>[];
              if (products.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No hay productos para configurar.'),
                );
              }

              final filtered = _filtered(products);
              final availableCount = products
                  .where((product) => (_available(product) ?? 0) > 0)
                  .length;
              final noStockCount = products
                  .where((product) => _available(product) == 0)
                  .length;
              final pendingCount = products
                  .where((product) => _available(product) == null)
                  .length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _metric(
                        icon: Icons.inventory_2_outlined,
                        label: 'Productos',
                        value: '${products.length}',
                      ),
                      _metric(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Con disponibilidad',
                        value: '$availableCount',
                      ),
                      _metric(
                        icon: Icons.remove_shopping_cart_outlined,
                        label: 'Sin stock',
                        value: '$noStockCount',
                      ),
                      _metric(
                        icon: Icons.pending_actions_outlined,
                        label: 'Por configurar',
                        value: '$pendingCount',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por código, producto o presentación',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 14),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 22),
                      child: Center(
                        child: Text(
                          'No se encontraron productos con ese criterio.',
                        ),
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 1050) {
                          return Column(
                            children: [
                              _desktopHeader(),
                              ...filtered.map(_desktopRow),
                            ],
                          );
                        }
                        return Column(
                          children: filtered.map(_compactCard).toList(),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
