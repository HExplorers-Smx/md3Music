import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md3music/modules/player/additional_lyric_stages.dart';
import 'package:md3music/widgets/apple_lyrics/models/lyric_line.dart';
import 'package:md3music/widgets/md3_lyric_preferences.dart';

void main() {
  final additionalModes = Md3LyricStageMode.values.where(
    (mode) => mode != Md3LyricStageMode.original &&
        mode != Md3LyricStageMode.glow &&
        mode != Md3LyricStageMode.partita,
  ).toList();

  test('all available choices have nonempty distinct labels', () {
    final modes = Md3LyricStageMode.values;
    expect(modes.length, 18);
    expect(additionalModes.length, 15);
    final labels = modes.map((mode) => mode.label).toList();
    expect(labels.toSet().length, modes.length);
    for (final mode in modes) {
      expect(mode.label.trim(), isNotEmpty);
      expect(mode.description.trim(), isNotEmpty);
      expect(mode.label.toLowerCase().contains('folia'), isFalse);
    }
  });

  testWidgets('every additional mode builds a real stage', (tester) async {
    const sample = [
      LyricLine(startTime: 0, duration: 1100, text: '前一句'),
      LyricLine(
        startTime: 1200,
        duration: 3000,
        text: '星光与你同行',
        translation: 'Walking with the stars',
        words: [
          LyricWord(startTime: 1200, duration: 500, text: '星光'),
          LyricWord(startTime: 1700, duration: 500, text: '与你'),
          LyricWord(startTime: 2200, duration: 700, text: '同行'),
        ],
      ),
      LyricLine(startTime: 4200, duration: 1500, text: '下一句'),
    ];

    for (final mode in additionalModes) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 600,
            child: AdditionalLyricStages(
              mode: mode,
              lines: sample,
              currentIndex: 1,
              elapsedMs: 2200,
              maxWidth: 390,
              maxHeight: 600,
            ),
          ),
        ),
      ));
      expect(find.byType(AdditionalLyricStages), findsOneWidget);
      expect(tester.takeException(), isNull, reason: mode.label);
    }
  });

  testWidgets('untimed lyrics remain renderable', (tester) async {
    for (final mode in additionalModes) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SizedBox(
          width: 320,
          height: 500,
          child: AdditionalLyricStages(
            mode: mode,
            lines: const [
              LyricLine(startTime: 0, duration: 5000, text: '无逐字时间'),
            ],
            currentIndex: 0,
            elapsedMs: 1800,
            maxWidth: 320,
            maxHeight: 500,
          ),
        )),
      ));
      expect(tester.takeException(), isNull, reason: mode.label);
    }
  });
}
