import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../widgets/apple_lyrics/models/lyric_line.dart';
import '../../widgets/md3_lyric_preferences.dart';

/// Additional animated stages, painted by Flutter with existing lyric timing.
class AdditionalLyricStages extends StatelessWidget {
  const AdditionalLyricStages({
    super.key,
    required this.mode,
    required this.lines,
    required this.currentIndex,
    required this.elapsedMs,
    required this.maxWidth,
    required this.maxHeight,
  });

  final Md3LyricStageMode mode;
  final List<LyricLine> lines;
  final int currentIndex;
  final double elapsedMs;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = Md3LyricPreferences.instance.customTextColor ?? cs.primary;
    final reduced = MediaQuery.of(context).disableAnimations;
    return Stack(fit: StackFit.expand, children: [
      if (mode != Md3LyricStageMode.still)
        CustomPaint(painter: _StageScenery(
          mode, reduced ? 0 : elapsedMs / 1000, accent, cs)),
      AnimatedSwitcher(
        duration: reduced ? Duration.zero : const Duration(milliseconds: 360),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _StageLayout(mode, lines, currentIndex, elapsedMs,
          maxWidth, maxHeight, cs, accent, reduced,
          key: ValueKey(mode.name + ':' + currentIndex.toString())),
      ),
    ]);
  }
}

class _StageLayout extends StatelessWidget {
  const _StageLayout(this.mode, this.lines, this.index, this.ms,
    this.width, this.height, this.cs, this.accent, this.reduced,
    {super.key});

  final Md3LyricStageMode mode;
  final List<LyricLine> lines;
  final int index;
  final double ms, width, height;
  final ColorScheme cs;
  final Color accent;
  final bool reduced;

  LyricLine get line => lines[index];
  LyricLine? get previous => index > 0 ? lines[index - 1] : null;
  LyricLine? get next => index + 1 < lines.length ? lines[index + 1] : null;
  double get time => ms / 1000;
  double get font => Md3LyricPreferences.instance.fontSize.clamp(20.0, 42.0)
      .toDouble();
  double get amplitude => reduced ? 0 : 1;
  String? get secondaryLine {
    final prefs = Md3LyricPreferences.instance;
    if (!prefs.showAuxiliary) return null;
    return prefs.displayMode == Md3LyricDisplayMode.roma
      ? line.roma : line.translation;
  }

  double _wordFraction(LyricWord word) {
    final begin = word.startTime.toDouble();
    final end = begin + word.duration;
    if (end <= begin) return ms >= begin ? 1.0 : 0.0;
    return ((ms - begin) / (end - begin)).clamp(0.0, 1.0).toDouble();
  }

  Widget _lyric({double scale = 1, Color? color,
    TextAlign alignment = TextAlign.center, int linesLimit = 5,
    bool luminous = false, LyricLine? source}) {
    final data = source ?? line;
    final active = color ?? accent;
    final prefs = Md3LyricPreferences.instance;
    final base = TextStyle(fontSize: font * scale, height: 1.25,
      fontWeight: prefs.fontWeight, fontFamily: prefs.effectiveFontFamily);
    return RichText(
      textAlign: alignment, softWrap: true, maxLines: linesLimit,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: base, children: data.words.isNotEmpty
        ? [
            for (final word in data.words)
              TextSpan(text: word.text, style: TextStyle(
                color: Color.lerp(cs.onSurface.withValues(alpha: .37),
                    active, _wordFraction(word)),
                shadows: luminous ? [Shadow(
                    color: active.withValues(alpha: .34 * _wordFraction(word)),
                    blurRadius: 14 * _wordFraction(word))] : null)),
          ]
        : [TextSpan(text: data.text, style: TextStyle(
            color: active, shadows: luminous
              ? [Shadow(color: active.withValues(alpha: .32),
                  blurRadius: 12)] : null))]),
    );
  }

  Widget _aux({double scale = .48}) {
    final text = secondaryLine;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(top: 14),
      child: Text(text, textAlign: TextAlign.center, maxLines: 3,
        overflow: TextOverflow.ellipsis, style: TextStyle(
        fontSize: (font * scale).clamp(12.0, 24.0).toDouble(),
        color: cs.onSurface.withValues(alpha: .68),
        fontFamily: Md3LyricPreferences.instance.effectiveFontFamily)));
  }

  Widget _other(LyricLine? data) => data == null
    ? const SizedBox.shrink()
    : Text(data.text, maxLines: 2, overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(color: cs.onSurface.withValues(alpha: .32),
        fontSize: font * .55));

  Widget _v(List<Widget> children) =>
      Column(mainAxisSize: MainAxisSize.min, children: children);

  Widget _fit(Widget content, {double fraction = .86}) {
    final w = math.max(170.0, width * fraction);
    final h = math.max(180.0, height * .89);
    return Center(child: Padding(padding: const EdgeInsets.all(8),
      child: FittedBox(fit: BoxFit.scaleDown,
        child: SizedBox(width: w, height: h,
          child: Center(child: content)))));
  }

  Widget _fume() => _fit(_v([
    _other(previous), const SizedBox(height: 20),
    Transform.translate(
      offset: Offset(math.sin(time * .33) * amplitude * 14, 0),
      child: _lyric(scale: 1.75, luminous: true)),
    _aux(), const SizedBox(height: 28), _other(next),
  ]), fraction: .95);

  String _glyph() {
    if (line.words.isNotEmpty) {
      for (final word in line.words) {
        if (ms >= word.startTime && ms < word.startTime + word.duration) {
          return word.text;
        }
      }
      return line.words.last.text;
    }
    return line.text.runes.isEmpty
      ? '' : String.fromCharCode(line.text.runes.first);
  }

  Widget _cadenza() => _fit(_v([
    SizedBox(height: font * 2.9, width: width * .74,
      child: Stack(alignment: Alignment.center, children: [
        for (var i = 0; i < 13; i++)
          Positioned(left: (i * 47 % 91) / 100 * width * .65,
            top: (i * 29 % 72).toDouble(),
            child: Opacity(opacity: .12 + (i % 3) * .08,
              child: Transform.rotate(
                angle: math.sin(time * .3 + i) * amplitude * .15,
                child: Text(_glyph(), style: TextStyle(
                  fontSize: 13.0 + (i % 5) * 4, color: cs.onSurface))))),
        Container(width: font * 2.3, height: font * 2.3,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle,
            border: Border.all(color: accent.withValues(alpha: .72)),
            boxShadow: [BoxShadow(color: accent.withValues(alpha: .17),
              blurRadius: 35)]),
          child: Text(_glyph(), style: TextStyle(
            color: accent, fontSize: font * 1.1))),
      ])),
    const SizedBox(height: 18),
    _lyric(scale: .8), _aux(scale: .42),
  ]));

  Widget _cappella() => _fit(_v([
    for (final (i, data) in [
      if (previous != null) previous!,
      line,
      if (next != null) next!,
    ].indexed)
      Align(
        alignment: data.agentId != null
          ? (data.agentId.hashCode.isEven
              ? Alignment.centerLeft : Alignment.centerRight)
          : (i.isEven ? Alignment.centerLeft : Alignment.centerRight),
        child: Container(
          constraints: BoxConstraints(maxWidth: width * .72),
          margin: const EdgeInsets.symmetric(vertical: 7),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
            color: identical(data, line)
              ? accent.withValues(alpha: .18)
              : cs.surfaceContainerHigh.withValues(alpha: .74)),
          child: identical(data, line)
            ? _v([_lyric(scale: .72), _aux(scale: .37)])
            : Text(data.text, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: font * .58,
                  color: cs.onSurfaceVariant)))),
  ]));

  Widget _tilt() => _fit(_v([
    Transform.rotate(angle: math.sin(time * .7) * amplitude * .055,
      child: _lyric(scale: 1.18, luminous: true)),
    const SizedBox(height: 17),
    Transform.rotate(angle: -.09, child: _aux(scale: .55)),
    const SizedBox(height: 30), _other(next),
  ]));

  Widget _diorama() => _fit(_v([
    Transform.translate(
      offset: Offset(10 * amplitude * math.sin(time * .5), -12),
      child: Opacity(opacity: .3, child: _other(previous))),
    Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: .4)),
        gradient: LinearGradient(colors: [
          cs.surfaceContainerHigh.withValues(alpha: .88),
          accent.withValues(alpha: .16)])),
      child: _v([_lyric(scale: 1.04, luminous: true), _aux()])),
    const SizedBox(height: 18),
    Transform.translate(
      offset: Offset(-10 * amplitude * math.sin(time * .5), 0),
      child: _other(next)),
  ]));

  Widget _pendolo() => _fit(_v([
    CustomPaint(size: Size(math.min(width * .32, 120.0),
        math.min(width * .32, 120.0)),
      painter: _ClockDial(time * amplitude, accent)),
    const SizedBox(height: 18),
    _lyric(scale: .98, luminous: true), _aux(),
  ]));

  Widget _sonnet() => _fit(Container(
    padding: const EdgeInsets.all(23),
    decoration: BoxDecoration(
      border: Border.all(color: accent.withValues(alpha: .58), width: 2),
      color: cs.surfaceContainerLow.withValues(alpha: .3)),
    child: _v([
      Align(alignment: Alignment.centerLeft,
        child: Text('01 / LYRICS', style: TextStyle(
          fontSize: 11, letterSpacing: 3, color: accent))),
      const SizedBox(height: 30),
      _lyric(scale: 1.22, luminous: true),
      const SizedBox(height: 20), _aux(),
      const SizedBox(height: 23),
      Divider(color: accent.withValues(alpha: .34)),
    ]),
  ));

  Widget _lumiere() => _fit(_v([
    Transform.translate(offset: Offset(0,
      amplitude * math.sin(time * .45) * 6),
      child: _lyric(scale: 1.28, luminous: true)),
    const SizedBox(height: 20), _aux(),
    const SizedBox(height: 25), _other(next),
  ]));

  Widget _hanabi() => _fit(_v([
    Container(padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(8)),
      child: _lyric(scale: 1.16, luminous: true)),
    const SizedBox(height: 22), _aux(),
    const SizedBox(height: 34), _other(next),
  ]));

  Widget _machi() => _fit(_v([
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 18),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: .8),
          width: 2),
        boxShadow: [BoxShadow(
          color: accent.withValues(alpha: .2), blurRadius: 26)]),
      child: _v([
        Text('NOW PLAYING', style: TextStyle(
          color: accent, fontSize: 11, letterSpacing: 3)),
        const SizedBox(height: 16),
        _lyric(scale: .86, luminous: true),
      ])),
    const SizedBox(height: 26), _other(next),
  ]));

  Widget _monet() => _fit(_v([
    Row(children: [
      Expanded(flex: 3, child: _v([
        Text('01 — LYRICS', style: TextStyle(
          color: accent, fontSize: 11, letterSpacing: 2)),
        const SizedBox(height: 25),
        _lyric(scale: .9, alignment: TextAlign.left),
        _aux(),
      ])),
      const SizedBox(width: 8),
      Expanded(flex: 2, child: Container(
        height: math.min(height * .36, 194.0),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(60),
            bottomRight: Radius.circular(82)),
          gradient: LinearGradient(colors: [
            accent.withValues(alpha: .73),
            cs.tertiary.withValues(alpha: .2)])))),
    ]),
    const SizedBox(height: 30), _other(next),
  ]));

  Widget _nebbia() => _fit(Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
    decoration: BoxDecoration(
      color: cs.surfaceContainerHighest.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(25),
      border: Border.all(color: cs.onSurface.withValues(alpha: .18))),
    child: _v([_lyric(scale: 1.12, luminous: true), _aux(),
      const SizedBox(height: 27), _other(next)]),
  ));

  Widget _claddagh() => _fit(_v([
    Transform.rotate(
      angle: math.sin(time * .32) * amplitude * .045,
      child: _lyric(scale: 1.08, luminous: true)),
    const SizedBox(height: 22), _aux(),
  ]));

  Widget _tempera() => _fit(_v([
    Container(width: width * .76, padding: const EdgeInsets.all(16),
      color: accent.withValues(alpha: .2),
      child: _lyric(scale: 1.06)),
    const SizedBox(height: 5),
    Container(width: width * .62, padding: const EdgeInsets.all(12),
      color: cs.tertiary.withValues(alpha: .16),
      child: _aux()),
    const SizedBox(height: 24), _other(next),
  ]));

  Widget _still() => _fit(_v([
    _other(previous), const SizedBox(height: 28),
    _lyric(scale: 1.02), _aux(),
    const SizedBox(height: 28), _other(next),
  ]));

  @override
  Widget build(BuildContext context) => switch (mode) {
    Md3LyricStageMode.fume => _fume(),
    Md3LyricStageMode.cadenza => _cadenza(),
    Md3LyricStageMode.cappella => _cappella(),
    Md3LyricStageMode.tilt => _tilt(),
    Md3LyricStageMode.diorama => _diorama(),
    Md3LyricStageMode.pendolo => _pendolo(),
    Md3LyricStageMode.sonnet => _sonnet(),
    Md3LyricStageMode.lumiere => _lumiere(),
    Md3LyricStageMode.hanabi => _hanabi(),
    Md3LyricStageMode.machi => _machi(),
    Md3LyricStageMode.monet => _monet(),
    Md3LyricStageMode.nebbia => _nebbia(),
    Md3LyricStageMode.claddagh => _claddagh(),
    Md3LyricStageMode.tempera => _tempera(),
    Md3LyricStageMode.still => _still(),
    _ => _still(),
  };
}

class _ClockDial extends CustomPainter {
  const _ClockDial(this.time, this.color);
  final double time;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .46;
    final pen = Paint()..color = color..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, pen);
    for (var i = 0; i < 24; i++) {
      final angle = i * math.pi / 12;
      final inner = radius - (i.isEven ? 11 : 6);
      canvas.drawLine(
        center + Offset(math.cos(angle) * inner,
          math.sin(angle) * inner),
        center + Offset(math.cos(angle) * radius,
          math.sin(angle) * radius), pen);
    }
    final angle = time * .3 - math.pi / 2;
    canvas.drawLine(center,
      center + Offset(math.cos(angle) * radius * .82,
        math.sin(angle) * radius * .82),
      pen..strokeWidth = 2.7);
  }

  @override
  bool shouldRepaint(covariant _ClockDial old) =>
    old.time != time || old.color != color;
}

class _StageScenery extends CustomPainter {
  const _StageScenery(this.mode, this.time, this.color, this.cs);
  final Md3LyricStageMode mode;
  final double time;
  final Color color;
  final ColorScheme cs;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width, h = size.height;
    final dim = Paint()..color = color.withValues(alpha: .12);
    final stroke = Paint()..color = cs.onSurface.withValues(alpha: .15)
      ..strokeWidth = 1.1..style = PaintingStyle.stroke;
    switch (mode) {
      case Md3LyricStageMode.fume:
        canvas.drawRect(Rect.fromLTWH(-w*.1,h*.24,w*1.2,h*.19), dim);
        for(var i=0;i<6;i++){
          canvas.drawLine(Offset(0,h*(.12+i*.14)),
            Offset(w,h*(.12+i*.14)),stroke);
        }
      case Md3LyricStageMode.cadenza:
        for(var i=0;i<12;i++){
          final t=time*.16+i*2.4;
          canvas.drawCircle(Offset(w*.5+math.cos(t)*w*.34,
            h*.45+math.sin(t*1.4)*h*.26),
            4.0+(i%4)*2,dim);
        }
      case Md3LyricStageMode.cappella:
        for(var i=0;i<6;i++){
          canvas.drawCircle(Offset(w*(.1+i*.16),h*.13),
            3.0+(i%3)*2,dim);
        }
      case Md3LyricStageMode.tilt:
        canvas.save();canvas.translate(w/2,h/2);canvas.rotate(-.1);
        canvas.drawLine(Offset(-w*.43,-h*.2),Offset(w*.43,-h*.2),
          stroke);
        canvas.drawLine(Offset(-w*.43,h*.22),Offset(w*.43,h*.22),
          stroke);
        canvas.restore();
      case Md3LyricStageMode.diorama:
        for(var i=0;i<7;i++) {
          final depth=i/7;
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(
              w*(.07+depth*.08)+math.sin(time*.3+i)*10,
              h*(.16+depth*.055),
              w*(.76-depth*.1), h*(.56-depth*.06)),
              const Radius.circular(12)),
            Paint()..color=color.withValues(alpha:.03+depth*.02));
        }
      case Md3LyricStageMode.pendolo:
        canvas.drawLine(Offset(0,h*.75),Offset(w,h*.75),stroke);
      case Md3LyricStageMode.sonnet:
        canvas.drawRect(Rect.fromLTWH(22,22,w-44,h-44),stroke);
      case Md3LyricStageMode.lumiere:
        for(var i=0;i<3;i++){
          final origin=Offset(w*(.15+i*.35),0);
          final x=w*(.25+i*.24)+math.sin(time*.3+i)*24;
          final path=Path()..moveTo(origin.dx,0)
            ..lineTo(x-w*.24,h*.83)
            ..lineTo(x+w*.24,h*.83)..close();
          canvas.drawPath(path,Paint()
            ..shader=LinearGradient(
              begin:Alignment.topCenter,end:Alignment.bottomCenter,
              colors:[color.withValues(alpha:.18),
                color.withValues(alpha:.008)])
            .createShader(Rect.fromLTWH(0,0,w,h)));
        }
      case Md3LyricStageMode.hanabi:
        for(var i=0;i<5;i++){
          final x=w*(.12+(i*31%78)/100);
          final y=h*(.13+(i*17%43)/100);
          final r=math.max(2.0,(math.sin(time*.65+i*2)+1)*17);
          final brush=Paint()
            ..color=(i.isEven?color:cs.secondary)
              .withValues(alpha:.35)..strokeWidth=1.8;
          for(var j=0;j<10;j++){
            final a=j*math.pi/5;
            canvas.drawLine(
              Offset(x+math.cos(a)*r*.38,
                y+math.sin(a)*r*.38),
              Offset(x+math.cos(a)*r,
                y+math.sin(a)*r),
              brush);
          }
        }
      case Md3LyricStageMode.machi:
        for(var i=0;i<13;i++) {
          final height=h*(.11+(i*7%13)/100);
          canvas.drawRect(Rect.fromLTWH(w*i/13,h-height,
            w/14,height), dim);
        }
      case Md3LyricStageMode.monet:
        canvas.drawCircle(Offset(w*.81,h*.21),w*.27,
          Paint()..color=cs.tertiary.withValues(alpha:.1));
      case Md3LyricStageMode.nebbia:
        final rain=Paint()..color=cs.onSurface.withValues(alpha:.13)
          ..strokeWidth=1.4..strokeCap=StrokeCap.round;
        for(var i=0;i<38;i++){
          final x=(i*67%101)/101*w;
          final y=((i*41%113)/113*h+time*(9+i%8))%h;
          canvas.drawLine(Offset(x,y),
            Offset(x-1.2,y+8+i%10),rain);
        }
      case Md3LyricStageMode.claddagh:
        canvas.save();canvas.translate(w/2,h/2);
        canvas.rotate(-.22+math.sin(time*.2)*.07);
        canvas.drawOval(Rect.fromCenter(center:Offset.zero,
          width:w*.82,height:h*.38),stroke);
        canvas.drawCircle(Offset(math.cos(time*.3)*w*.41,
          math.sin(time*.3)*h*.19),6,
          Paint()..color=color.withValues(alpha:.7));
        canvas.restore();
      case Md3LyricStageMode.tempera:
        canvas.drawRect(Rect.fromLTWH(0,0,w,h*.34),dim);
        canvas.drawRect(Rect.fromLTWH(0,h*.73,w,h*.27),
          Paint()..color=cs.secondary.withValues(alpha:.1));
      case Md3LyricStageMode.still:
      case Md3LyricStageMode.original:
      case Md3LyricStageMode.glow:
      case Md3LyricStageMode.partita:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _StageScenery old) =>
      old.mode != mode || old.time != time ||
      old.color != color || old.cs != cs;
}
