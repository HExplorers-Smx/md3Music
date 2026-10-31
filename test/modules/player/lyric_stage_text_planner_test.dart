import 'package:flutter_test/flutter_test.dart';
import 'package:md3music/modules/player/stage_lyrics_view.dart';
import 'package:md3music/widgets/apple_lyrics/models/lyric_line.dart';

void main() {
  test('untimed lyrics stay untimed', () {
    const line = LyricLine(
      startTime: 1000,
      duration: 3000,
      text: '夜空中最亮的星',
    );
    final chunks = StageTextPlanner.chunksFor(line, maxCharacters: 3);
    expect(chunks.map((chunk) => chunk.text).join(), line.text);
    expect(chunks.every((chunk) =>
      chunk.units.every((unit) => !unit.timed)), isTrue);
  });

  test('word timestamps and punctuation remain in order', () {
    const line = LyricLine(
      startTime: 500,
      duration: 2000,
      text: 'Hello,世界',
      words: [
        LyricWord(text: 'Hello', startTime: 500, duration: 400),
        LyricWord(text: ',', startTime: 900, duration: 50),
        LyricWord(text: '世', startTime: 950, duration: 300),
        LyricWord(text: '界', startTime: 1250, duration: 300),
      ],
    );
    final chunks = StageTextPlanner.chunksFor(line, maxCharacters: 5);
    expect(chunks.map((chunk) => chunk.text).join(), 'Hello,世界');
    expect(chunks.first.text, 'Hello,');
    expect(chunks.first.units.first.startMs, 500);
    expect(chunks.last.units.last.endMs, 1550);
  });

  test('empty lines and invalid target sizes', () {
    const line = LyricLine(startTime: 0, duration: 0, text: '');
    expect(StageTextPlanner.chunksFor(line), isEmpty);
    expect(() => StageTextPlanner.chunksFor(line, maxCharacters: 0),
        throwsArgumentError);
  });
}
