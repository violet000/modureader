import 'package:modu_reader/config/shared_preference_provider.dart';
import 'package:flutter/material.dart';

/// E-ink keeps the plain widgets. Other modes use a flat content surface.
bool get auroraSuppressed =>
    Prefs().isInitialized && Prefs().eInkMode;

class AuroraCanvas extends StatelessWidget {
  const AuroraCanvas({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (auroraSuppressed) return child;
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              const Color(0xFF14B8A6).withValues(alpha: dark ? 0.34 : 0.22),
              scheme.surface,
            ),
            Color.alphaBlend(
              scheme.primary.withValues(alpha: dark ? 0.16 : 0.08),
              scheme.surface,
            ),
            scheme.surface,
          ],
          stops: const [0, 0.22, 0.62],
        ),
      ),
      child: child,
    );
  }
}

/// Quiet brand mark for the side rail. Page titles use type, not a badge.
class GlowMark extends StatelessWidget {
  const GlowMark({super.key, required this.icon, this.size = 36});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (auroraSuppressed) {
      return Icon(icon, size: size * 0.62);
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, const Color(0xFF14B8A6)],
        ),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.radius = 12,
    this.glow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Padding(padding: padding ?? EdgeInsets.zero, child: child);
    if (auroraSuppressed) {
      return Padding(padding: margin ?? EdgeInsets.zero, child: content);
    }
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: scheme.surface,
        border: Border.all(
          color: glow
              ? scheme.primary.withValues(alpha: 0.28)
              : scheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: glow ? 0.08 : 0.04),
            blurRadius: glow ? 18 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
