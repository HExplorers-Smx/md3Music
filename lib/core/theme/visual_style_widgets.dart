import 'dart:ui';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_miuix/miuix.dart' as miuix;
import 'visual_style_theme.dart';

/// Shared styled section, no extra network fetches or playback listeners.
class VisualSection extends StatelessWidget {
  const VisualSection({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = VisualTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    if (!t.isGlass) {
      return Material(
        color: t.mode.name == 'material3' ? cs.surfaceContainer : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(t.corner),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(t.corner),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: cs.surface.withValues(alpha: 0.66),
            shape: miuix.MiuixSquircleBorder(cornerRadius: t.corner),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
