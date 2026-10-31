import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../widgets/apple_lyrics/models/lyric_line.dart';
import '../../widgets/md3_lyric_preferences.dart';
import 'lyrics_view.dart';
import 'additional_lyric_stages.dart';

// Native lyric stages share the existing timeline and audio position.
// Source and license acknowledgements: docs/lyrics-animation-attribution.md.
class StageLyricsView extends StatelessWidget {
  const StageLyricsView({
    super.key,
    required this.lyrics,
    required this.parsedLyrics,
    required this.position,
    required this.positionListenable,
    required this.adaptPosition,
    required this.onSeek,
    required this.doubleTapToJump,
    required this.isPlaying,
  });

  final String lyrics;
  final List<LyricLine>? parsedLyrics;
  final Duration position;
  final ValueListenable<Duration>? positionListenable;
  final Duration Function(Duration)? adaptPosition;
  final ValueChanged<Duration> onSeek;
  final bool doubleTapToJump;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Md3LyricPreferences.instance,
        builder: (context, _) {
          final mode = Md3LyricPreferences.instance.stageMode;
          final lines = parsedLyrics;
          if (mode == Md3LyricStageMode.original ||
              lines == null ||
              lines.isEmpty) {
            return LyricsView(
              lyrics: lyrics,
              parsedLyrics: lines,
              position: position,
              positionListenable: positionListenable,
              adaptPosition: adaptPosition,
              onSeek: onSeek,
              doubleTapToJump: doubleTapToJump,
            );
          }
          return AnimatedLyricStage(
            lines: lines,
            mode: mode,
            position: position,
            positionListenable: positionListenable,
            adaptPosition: adaptPosition,
            onSeek: onSeek,
            isPlaying: isPlaying,
            doubleTapToJump: doubleTapToJump,
          );
        },
      );
}

@immutable
class StageTextUnit {
  const StageTextUnit(this.text, {this.startMs, this.endMs});
  final String text;
  final int? startMs;
  final int? endMs;
  bool get timed => startMs != null && endMs != null;
}

@immutable
class StageTextChunk {
  const StageTextChunk(this.units);
  final List<StageTextUnit> units;
  String get text => units.map((unit) => unit.text).join();
}

// Preserve source timestamps. Plain LRC uses untimed units, never estimated ones.
class StageTextPlanner {
  const StageTextPlanner._();

  static List<StageTextUnit> unitsFor(LyricLine line) {
    if (line.words.isNotEmpty) {
      return line.words
          .map((word) => StageTextUnit(
                word.text,
                startMs: word.startTime,
                endMs: word.startTime + word.duration,
              ))
          .toList(growable: false);
    }
    return line.text.runes
        .map((point) => StageTextUnit(String.fromCharCode(point)))
        .toList(growable: false);
  }

  static List<StageTextChunk> chunksFor(
    LyricLine line, {
    int maxCharacters = 11,
  }) {
    if (maxCharacters < 1) throw ArgumentError.value(maxCharacters);
    final result = <StageTextChunk>[];
    var current = <StageTextUnit>[];
    var count = 0;
    final punctuation = RegExp(r'^[，。、！？：；,.!?;:]$');
    for (final unit in unitsFor(line)) {
      final n = unit.text.runes.length;
      if (current.isNotEmpty &&
          count + n > maxCharacters &&
          !punctuation.hasMatch(unit.text)) {
        result.add(StageTextChunk(List.unmodifiable(current)));
        current = <StageTextUnit>[];
        count = 0;
      }
      current.add(unit);
      count += n;
    }
    if (current.isNotEmpty) {
      result.add(StageTextChunk(List.unmodifiable(current)));
    }
    return result;
  }
}

class AnimatedLyricStage extends StatefulWidget {
  const AnimatedLyricStage({
    super.key,
    required this.lines,
    required this.mode,
    required this.position,
    required this.positionListenable,
    required this.adaptPosition,
    required this.onSeek,
    required this.isPlaying,
    required this.doubleTapToJump,
  });

  final List<LyricLine> lines;
  final Md3LyricStageMode mode;
  final Duration position;
  final ValueListenable<Duration>? positionListenable;
  final Duration Function(Duration)? adaptPosition;
  final ValueChanged<Duration> onSeek;
  final bool isPlaying;
  final bool doubleTapToJump;

  @override
  State<AnimatedLyricStage> createState() =>
      _AnimatedLyricStageState();
}

class _AnimatedLyricStageState extends State<AnimatedLyricStage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration? _lastTick;
  double _timeMs = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _readPosition(notify: false);
    widget.positionListenable?.addListener(_readPosition);
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant AnimatedLyricStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.positionListenable != widget.positionListenable) {
      oldWidget.positionListenable?.removeListener(_readPosition);
      widget.positionListenable?.addListener(_readPosition);
      _readPosition();
    } else if (widget.positionListenable == null &&
        oldWidget.position != widget.position) {
      _readPosition();
    }
    _syncTicker();
  }

  void _readPosition({bool notify = true}) {
    final position = widget.positionListenable?.value ?? widget.position;
    final adjusted = widget.adaptPosition?.call(position) ?? position;
    _timeMs = adjusted.inMilliseconds.toDouble();
    if (notify && mounted) setState(() {});
  }

  void _syncTicker() {
    if (widget.isPlaying &&
        widget.lines.isNotEmpty &&
        widget.mode != Md3LyricStageMode.still) {
      if (!_ticker.isActive) {
        _lastTick = null;
        _ticker.start();
      }
    } else if (_ticker.isActive) {
      _ticker.stop();
      _lastTick = null;
    }
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final previous = _lastTick;
    _lastTick = elapsed;
    if (previous == null) return;
    final delta = (elapsed - previous).inMilliseconds.clamp(0, 50);
    setState(() => _timeMs += delta);
  }

  @override
  void dispose() {
    widget.positionListenable?.removeListener(_readPosition);
    _ticker.dispose();
    super.dispose();
  }

  int _lineIndex() {
    final lines = widget.lines;
    if (lines.isEmpty) return -1;
    var lo = 0;
    var hi = lines.length;
    while (lo < hi) {
      final middle = (lo + hi) ~/ 2;
      if (lines[middle].startTime <= _timeMs) {
        lo = middle + 1;
      } else {
        hi = middle;
      }
    }
    return (lo - 1).clamp(0, lines.length - 1).toInt();
  }

  double _progress(StageTextUnit unit) {
    final start = unit.startMs;
    final end = unit.endMs;
    if (start == null || end == null) return 1.0;
    if (end <= start) return _timeMs >= start ? 1.0 : 0.0;
    return ((_timeMs - start) / (end - start)).clamp(0.0, 1.0).toDouble();
  }

  TextSpan _spanFor(
    List<StageTextUnit> units,
    Color active,
    Color inactive,
  ) {
    return TextSpan(children: [
      for (final unit in units)
        TextSpan(
          text: unit.text,
          style: TextStyle(
            color: Color.lerp(inactive, active, _progress(unit)),
            shadows: [
              Shadow(
                color: active.withValues(alpha: 0.36 * _progress(unit)),
                blurRadius: 12 * _progress(unit),
              ),
            ],
          ),
        ),
    ]);
  }

  void _seekToLine(int index) {
    if (index < 0 || index >= widget.lines.length) return;
    widget.onSeek(Duration(milliseconds: widget.lines[index].startTime));
  }

  Widget _glowStage(BuildContext context, int index) {
    final prefs = Md3LyricPreferences.instance;
    final cs = Theme.of(context).colorScheme;
    final line = widget.lines[index];
    final units = StageTextPlanner.unitsFor(line);
    final fontSize = prefs.fontSize.clamp(20.0, 46.0).toDouble();
    final accent = prefs.customTextColor ?? cs.primary;
    final dim = cs.onSurface.withValues(alpha: 0.34);
    final reduce = MediaQuery.of(context).disableAnimations;
    final drift = reduce ? 0.0 : math.sin(_timeMs / 650.0) * 3.5;
    final next = index + 1 < widget.lines.length
        ? widget.lines[index + 1].text
        : '';
    final auxiliary = prefs.displayMode == Md3LyricDisplayMode.roma
        ? line.roma
        : line.translation;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: AnimatedSwitcher(
          duration: reduce ? Duration.zero : const Duration(milliseconds: 360),
          child: Column(
            key: ValueKey(index),
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.translate(
                offset: Offset(0, drift),
                child: RichText(
                  textAlign: TextAlign.center,
                  softWrap: true,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: fontSize,
                      height: 1.38,
                      fontFamily: prefs.effectiveFontFamily,
                      fontWeight: prefs.fontWeight,
                    ),
                    children: [_spanFor(units, accent, dim)],
                  ),
                ),
              ),
              if (prefs.showAuxiliary && auxiliary != null &&
                  auxiliary.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  auxiliary,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.68),
                    fontSize: (fontSize * 0.51).clamp(12.0, 23.0).toDouble(),
                    fontFamily: prefs.effectiveFontFamily,
                  ),
                ),
              ],
              if (next.isNotEmpty) ...[
                const SizedBox(height: 38),
                Text(
                  next,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: dim,
                    fontSize: (fontSize * 0.59).clamp(13.0, 26.0).toDouble(),
                    fontFamily: prefs.effectiveFontFamily,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _partitaStage(BuildContext context, int index, double width) {
    final prefs = Md3LyricPreferences.instance;
    final cs = Theme.of(context).colorScheme;
    final line = widget.lines[index];
    final chunks = StageTextPlanner.chunksFor(
      line, maxCharacters: width < 340 ? 8 : 12,
    );
    final accent = prefs.customTextColor ?? cs.primary;
    final dim = cs.onSurface.withValues(alpha: 0.36);
    final reduce = MediaQuery.of(context).disableAnimations;
    final fontSize = prefs.fontSize.clamp(20.0, 42.0).toDouble();
    final auxiliary = prefs.displayMode == Md3LyricDisplayMode.roma
        ? line.roma
        : line.translation;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: AnimatedSwitcher(
          duration: reduce ? Duration.zero : const Duration(milliseconds: 300),
          child: SizedBox(
            key: ValueKey(index),
            width: width,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: SizedBox(
                width: width * 0.89,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < chunks.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                          top: i == 0 ? 0 : fontSize * 0.4,
                        ),
                        child: Align(
                          alignment: switch (i % 3) {
                            0 => Alignment.centerLeft,
                            1 => Alignment.centerRight,
                            _ => Alignment.center,
                          },
                          child: Transform.translate(
                            offset: reduce
                                ? Offset.zero
                                : Offset(
                                    math.sin(_timeMs / 720 + i) * 4,
                                    math.cos(_timeMs / 900 + i) * 3,
                                  ),
                            child: RichText(
                              maxLines: 3,
                              textAlign: switch (i % 3) {
                                0 => TextAlign.left,
                                1 => TextAlign.right,
                                _ => TextAlign.center,
                              },
                              text: TextSpan(
                                style: TextStyle(
                                  height: 1.22,
                                  fontSize: fontSize,
                                  fontFamily: prefs.effectiveFontFamily,
                                  fontWeight: prefs.fontWeight,
                                ),
                                children: [_spanFor(chunks[i].units, accent, dim)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (prefs.showAuxiliary &&
                        auxiliary != null && auxiliary.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        auxiliary,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.62),
                          fontFamily: prefs.effectiveFontFamily,
                          fontSize: (fontSize * 0.52).clamp(12.0, 23.0).toDouble(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lines.isEmpty) {
      return const Center(child: Text('暂无歌词'));
    }
    final index = _lineIndex();
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cs = Theme.of(context).colorScheme;
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.doubleTapToJump ? null : () => _seekToLine(index),
            onDoubleTap: widget.doubleTapToJump
                ? () => _seekToLine(index)
                : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.08),
                  radius: 1.1,
                  colors: [
                    cs.primary.withValues(alpha: 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SizedBox.expand(
                child: switch (widget.mode) {
                  Md3LyricStageMode.glow =>
                    _glowStage(context, index),
                  Md3LyricStageMode.partita =>
                    _partitaStage(context, index, constraints.maxWidth),
                  _ => AdditionalLyricStages(
                    mode: widget.mode,
                    lines: widget.lines,
                    currentIndex: index,
                    elapsedMs: _timeMs,
                    maxWidth: constraints.maxWidth,
                    maxHeight: constraints.maxHeight,
                  ),
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
