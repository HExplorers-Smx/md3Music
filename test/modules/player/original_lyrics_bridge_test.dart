import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md3music/modules/player/original_lyrics_webview.dart';
import 'package:md3music/widgets/apple_lyrics/models/lyric_line.dart';
import 'package:md3music/widgets/md3_lyric_preferences.dart';

void main() {
  test('every selectable animation has a renderer registry ID', () {
    final ids = Md3LyricStageMode.values
        .where((mode) => mode != Md3LyricStageMode.original)
        .map(OriginalLyricsWebHost.modeId).toList();
    expect(ids.length, 17);
    expect(ids.toSet().length, 17);
    expect(OriginalLyricsWebHost.modeId(Md3LyricStageMode.glow), 'classic');
    expect(OriginalLyricsWebHost.modeId(Md3LyricStageMode.diorama),
        'diorama');
    expect(OriginalLyricsWebHost.modeId(Md3LyricStageMode.nebbia), 'nebbia');
  });

  test('word timestamps use absolute milliseconds converted to seconds', () {
    const line = LyricLine(
      startTime: 2200,
      duration: 1800,
      text: '星光',
      translation: 'Starlight',
      roma: 'hoshikari',
      agentId: 'v1',
      words: [
        LyricWord(text: '星', startTime: 2200, duration: 250),
        LyricWord(text: '光', startTime: 2450, duration: 400),
      ],
    );
    final result = OriginalLyricsWebHost.serializeLine(line);
    expect(result['startTime'], 2.2);
    expect(result['endTime'], 4);
    expect(result['fullText'], '星光');
    expect(result['translation'], 'Starlight');
    expect(result['romanization'], 'hoshikari');
    expect(result['agentId'], 'v1');
    final words = result['words'] as List;
    expect(words[0]['startTime'], 2.2);
    expect(words[0]['endTime'], 2.45);
    expect(words[1]['endTime'], 2.85);
  });

  test('ordinary LRC contains no fabricated word timestamps', () {
    const line = LyricLine(
      startTime: 0, duration: 2400, text: '只有行级时间',
    );
    expect(OriginalLyricsWebHost.serializeLine(line)['words'], isEmpty);
  });

  test('theme hex color drops alpha and preserves RGB channels', () {
    expect(OriginalLyricsWebHost.colorHex(const Color(0x8834abef)),
        '#34abef');
  });
}
