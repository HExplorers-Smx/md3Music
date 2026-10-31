import 'package:material_ui/material_ui.dart';
import 'package:flutter_miuix/miuix.dart' as miuix;
import 'visual_style_mode.dart';

/// One style token source for every screen. Color still comes from the
/// application's current dynamic/cover/wallpaper seed and light/dark mode.
class VisualTokens extends ThemeExtension<VisualTokens> {
  const VisualTokens({
    required this.mode,
    required this.corner,
    required this.coverCorner,
    required this.rowCorner,
  });

  final VisualStyleMode mode;
  final double corner;
  final double coverCorner;
  final double rowCorner;
  bool get isGlass => mode == VisualStyleMode.miuixGlass;

  static const defaults = VisualTokens(
    mode: VisualStyleMode.expressive,
    corner: 28, coverCorner: 16, rowCorner: 18,
  );

  static VisualTokens of(BuildContext context) =>
      Theme.of(context).extension<VisualTokens>() ?? defaults;

  @override
  VisualTokens copyWith({
    VisualStyleMode? mode, double? corner,
    double? coverCorner, double? rowCorner,
  }) => VisualTokens(
    mode: mode ?? this.mode,
    corner: corner ?? this.corner,
    coverCorner: coverCorner ?? this.coverCorner,
    rowCorner: rowCorner ?? this.rowCorner,
  );

  @override
  VisualTokens lerp(ThemeExtension<VisualTokens>? other, double t) {
    if (other is! VisualTokens) return this;
    return VisualTokens(
      mode: t < 0.5 ? mode : other.mode,
      corner: corner + (other.corner - corner) * t,
      coverCorner: coverCorner + (other.coverCorner - coverCorner) * t,
      rowCorner: rowCorner + (other.rowCorner - rowCorner) * t,
    );
  }
}

class VisualStyleTheme {
  VisualStyleTheme._();

  static ThemeData apply(ThemeData base, VisualStyleMode mode) {
    final cs = base.colorScheme;
    final corner = switch (mode) {
      VisualStyleMode.material3 => 16.0,
      VisualStyleMode.expressive => 28.0,
      VisualStyleMode.miuixGlass => 26.0,
    };
    final tokens = VisualTokens(
      mode: mode,
      corner: corner,
      coverCorner: mode == VisualStyleMode.material3 ? 8 : 16,
      rowCorner: mode == VisualStyleMode.material3 ? 12 : 20,
    );
    final shape = mode == VisualStyleMode.miuixGlass
        ? const miuix.MiuixSquircleBorder(cornerRadius: 26)
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(corner));
    final outlined = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(
        mode == VisualStyleMode.material3 ? 12 : 20,
      ),
    );
    final surface = mode == VisualStyleMode.material3
        ? cs.surfaceContainer : cs.surfaceContainerLow;
    return base.copyWith(
      cardTheme: CardThemeData(
        shape: shape,
        color: surface,
        elevation: mode == VisualStyleMode.material3 ? 1 : 0,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: mode == VisualStyleMode.material3 ? outlined : const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: outlined,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: outlined,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: mode == VisualStyleMode.miuixGlass
            ? cs.surface.withValues(alpha: 0.90)
            : cs.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(corner)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(corner),
          borderSide: BorderSide(
            color: mode == VisualStyleMode.material3
                ? cs.outlineVariant : Colors.transparent,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(corner),
          borderSide: BorderSide(color: cs.primary, width: 1.6),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: shape,
        backgroundColor: surface,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(corner)),
        ),
        backgroundColor: surface,
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: mode == VisualStyleMode.material3
            ? cs.surface : cs.surfaceContainerLow,
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: mode == VisualStyleMode.material3 ? outlined : const StadiumBorder(),
      ),
      extensions: <ThemeExtension<dynamic>>[
        ...base.extensions.values,
        tokens,
      ],
    );
  }
}
