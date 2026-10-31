import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md3music/core/theme/visual_style_mode.dart';
import 'package:md3music/core/theme/visual_style_theme.dart';

void main() {
  test('theme preferences survive across all supported styles', () {
    for (final style in VisualStyleMode.values) {
      expect(VisualStyleMode.parse(style.name), style);
    }
    expect(VisualStyleMode.parse('invalid'), VisualStyleMode.expressive);
    expect(VisualStyleMode.parse(null), VisualStyleMode.expressive);
  });

  testWidgets('all three themes expose consistent tokens', (tester) async {
    for (final style in VisualStyleMode.values) {
      await tester.pumpWidget(MaterialApp(
        theme: VisualStyleTheme.apply(
          ThemeData(colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF386592),
          )),
          style,
        ),
        home: Builder(builder: (context) {
          final t = VisualTokens.of(context);
          expect(t.mode, style);
          expect(t.corner, greaterThanOrEqualTo(16));
          expect(t.coverCorner, greaterThanOrEqualTo(8));
          expect(t.isGlass, style == VisualStyleMode.miuixGlass);
          return const Scaffold(body: Text('主题可用'));
        }),
      ));
      expect(find.text('主题可用'), findsOneWidget);
    }
  });
}
