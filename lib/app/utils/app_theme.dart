import 'package:flutter/material.dart';

class SigmaColors {
  static const primary = Color(0xFFE0007A);
  static const primaryDark = Color(0xFF9B0055);
  static const secondary = Color(0xFF2F80ED);
  static const success = Color(0xFF19A974);
  static const warning = Color(0xFFFFB020);
  static const danger = Color(0xFFE53935);
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF6B7280);
  static const surface = Color(0xFFF7F8FC);
}

class SigmaGradients {
  static const primary = LinearGradient(
    colors: [SigmaColors.primary, SigmaColors.primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const dark = LinearGradient(
    colors: [Color(0xFF111827), Color(0xFF2D0A25)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class SigmaCard extends StatelessWidget {
  const SigmaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.07)
              : const Color(0xFFE7EAF2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.045),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SigmaMetricCard extends StatelessWidget {
  const SigmaMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color = SigmaColors.primary,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SigmaCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SigmaPill extends StatelessWidget {
  const SigmaPill({
    super.key,
    required this.label,
    required this.icon,
    this.color = SigmaColors.primary,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
