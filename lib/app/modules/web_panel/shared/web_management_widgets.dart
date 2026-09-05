import 'package:flutter/material.dart';

import '../../../utils/app_theme.dart';

List<Map<String, dynamic>> mapList(dynamic raw) {
  if (raw is! List) return <Map<String, dynamic>>[];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

Map<String, dynamic> mapValue(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return <String, dynamic>{};
}

String nestedText(
  Map<String, dynamic> source,
  String path, [
  String fallback = '-',
]) {
  dynamic current = source;
  for (final part in path.split('.')) {
    if (current is Map && current.containsKey(part)) {
      current = current[part];
    } else {
      return fallback;
    }
  }
  final value = current?.toString().trim() ?? '';
  return value.isEmpty ? fallback : value;
}

int? intValue(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

double? doubleValue(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

BoxDecoration managementBox() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: const Color(0xFFE7EAF0)),
  boxShadow: [
    BoxShadow(
      color: const Color(0xFF101828).withOpacity(.045),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ],
);

void showWebMessage(
  BuildContext context,
  String message, {
  bool error = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final color = error ? SigmaColors.danger : SigmaColors.success;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: 430,
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}

class WebPrimaryButton extends StatelessWidget {
  const WebPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add_rounded,
    this.filled = true,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool filled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label),
            ],
          );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(13),
    );

    if (!filled) {
      return OutlinedButton(
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: SigmaColors.primary,
          side: const BorderSide(color: Color(0xFFD8DEE9)),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
          shape: shape,
          backgroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
        child: child,
      );
    }

    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: SigmaColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        elevation: 0,
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
      child: child,
    );
  }
}

class WebFilterCard extends StatelessWidget {
  const WebFilterCard({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: managementBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: SigmaColors.primary.withOpacity(.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: SigmaColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: SigmaColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Filtra la información o ejecuta una acción principal.',
                      style: TextStyle(
                        color: SigmaColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: children),
        ],
      ),
    );
  }
}

class WebFieldBox extends StatelessWidget {
  const WebFieldBox({super.key, required this.child, this.width = 250});
  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: child);
}

class WebStatusChip extends StatelessWidget {
  const WebStatusChip({super.key, required this.label, required this.active});
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? SigmaColors.success : SigmaColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class WebTableContainer extends StatelessWidget {
  const WebTableContainer({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    return Container(
      decoration: managementBox(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 17, 20, 15),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.view_list_rounded,
                    size: 20,
                    color: SigmaColors.ink,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: SigmaColors.ink,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEAECF0)),
          Theme(
            data: baseTheme.copyWith(
              dataTableTheme: DataTableThemeData(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFF8FAFC),
                ),
                headingTextStyle: const TextStyle(
                  color: Color(0xFF475467),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
                dataTextStyle: const TextStyle(
                  color: SigmaColors.ink,
                  fontWeight: FontWeight.w600,
                ),
                dividerThickness: .7,
                horizontalMargin: 18,
                columnSpacing: 24,
                dataRowMinHeight: 58,
                dataRowMaxHeight: 72,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class WebAsyncBody extends StatelessWidget {
  const WebAsyncBody({
    super.key,
    required this.loading,
    required this.error,
    required this.empty,
    required this.child,
    this.emptyMessage = 'No se encontraron registros.',
  });

  final bool loading;
  final String? error;
  final bool empty;
  final Widget child;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2.5),
              SizedBox(height: 12),
              Text(
                'Cargando información...',
                style: TextStyle(
                  color: SigmaColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (error != null) {
      return _WebStateBox(
        icon: Icons.error_outline_rounded,
        title: 'No se pudo cargar la información',
        message: error!,
        color: SigmaColors.danger,
      );
    }
    if (empty) {
      return _WebStateBox(
        icon: Icons.inbox_outlined,
        title: 'Sin resultados',
        message: emptyMessage,
        color: SigmaColors.muted,
      );
    }
    return child;
  }
}

class _WebStateBox extends StatelessWidget {
  const _WebStateBox({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: SigmaColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: SigmaColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration webInputDecoration(String label, {String? hint}) {
  const borderColor = Color(0xFFDDE2EA);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    floatingLabelBehavior: FloatingLabelBehavior.auto,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    labelStyle: const TextStyle(
      color: Color(0xFF667085),
      fontWeight: FontWeight.w700,
    ),
    hintStyle: const TextStyle(
      color: Color(0xFF98A2B3),
      fontWeight: FontWeight.w500,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: SigmaColors.primary, width: 1.7),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: SigmaColors.danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: SigmaColors.danger, width: 1.7),
    ),
  );
}

class WebDialogHeader extends StatelessWidget {
  const WebDialogHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: SigmaColors.primary.withOpacity(.09),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: SigmaColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: SigmaColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: SigmaColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class WebFormSectionTitle extends StatelessWidget {
  const WebFormSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: SigmaColors.ink),
          ),
          const SizedBox(width: 9),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: SigmaColors.ink,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: SigmaColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class WebInfoBanner extends StatelessWidget {
  const WebInfoBanner({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.color = SigmaColors.primary,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(.065),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withOpacity(.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: SigmaColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Contenedor visual reutilizable para formularios Crear/Editar.
/// Mantiene la jerarquía de información sin convertir cada pantalla en una
/// sucesión de campos sin contexto.
class WebFormSectionCard extends StatelessWidget {
  const WebFormSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EAF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WebFormSectionTitle(title: title, subtitle: subtitle, icon: icon),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Dato sencillo para las fichas de solo lectura del panel web.
class WebDetailItem {
  const WebDetailItem({required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final IconData? icon;
}

/// Sección de una ficha de detalle. Puede combinar datos textuales y un
/// widget adicional (por ejemplo, un mapa) sin reutilizar formularios
/// deshabilitados.
class WebDetailSection {
  const WebDetailSection({
    required this.title,
    this.subtitle,
    this.icon,
    this.items = const <WebDetailItem>[],
    this.child,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<WebDetailItem> items;
  final Widget? child;
}

Future<void> showWebDetailDialog({
  required BuildContext context,
  required String title,
  required String subtitle,
  required IconData icon,
  required List<WebDetailSection> sections,
  String closeLabel = 'Cerrar',
  String? editLabel,
  VoidCallback? onEdit,
  double width = 780,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 22),
        title: WebDialogHeader(title: title, subtitle: subtitle, icon: icon),
        content: SizedBox(
          width: width,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 680),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < sections.length; index++) ...[
                    _WebDetailSectionCard(section: sections[index]),
                    if (index < sections.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(closeLabel),
          ),
          if (onEdit != null)
            WebPrimaryButton(
              label: editLabel ?? 'Editar',
              icon: Icons.edit_outlined,
              onPressed: () {
                Navigator.pop(dialogContext);
                onEdit();
              },
            ),
        ],
      );
    },
  );
}

class _WebDetailSectionCard extends StatelessWidget {
  const _WebDetailSectionCard({required this.section});

  final WebDetailSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WebFormSectionTitle(
            title: section.title,
            subtitle: section.subtitle,
            icon: section.icon,
          ),
          if (section.items.isNotEmpty) ...[
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 580;
                final itemWidth = compact
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: section.items
                      .map(
                        (item) => SizedBox(
                          width: itemWidth,
                          child: _WebDetailValue(item: item),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
          if (section.child != null) ...[
            if (section.items.isNotEmpty) const SizedBox(height: 14),
            section.child!,
          ],
        ],
      ),
    );
  }
}

class _WebDetailValue extends StatelessWidget {
  const _WebDetailValue({required this.item});

  final WebDetailItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDF0F4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.icon != null) ...[
            Icon(item.icon, size: 18, color: SigmaColors.primary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    color: SigmaColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  item.value.trim().isEmpty ? '-' : item.value,
                  style: const TextStyle(
                    color: SigmaColors.ink,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
