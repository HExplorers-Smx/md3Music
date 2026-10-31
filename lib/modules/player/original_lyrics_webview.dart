import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/platform_capabilities.dart';
import '../../core/services/spectrum_service.dart';
import 'original_lyrics_server.dart';
import '../../widgets/apple_lyrics/models/lyric_line.dart';
import '../../widgets/md3_lyric_preferences.dart';

/// Original browser runtime; only enabled after its offline build is bundled.
class OriginalLyricsWebHost extends StatefulWidget {
  const OriginalLyricsWebHost({
    super.key, required this.lines, required this.mode,
    required this.position, required this.positionListenable,
    required this.adaptPosition, required this.isPlaying,
    required this.onSeek, required this.fallback,
    this.songTitle, this.songArtist, this.songAlbum, this.coverUrl,
  });

  final List<LyricLine> lines;
  final Md3LyricStageMode mode;
  final Duration position;
  final ValueListenable<Duration>? positionListenable;
  final Duration Function(Duration)? adaptPosition;
  final bool isPlaying;
  final ValueChanged<Duration> onSeek;
  final Widget fallback;
  final String? songTitle, songArtist, songAlbum, coverUrl;

  static Future<bool> bundleAvailable() async {
    if (!isAndroidPlatform) return false;
    try {
      final data = jsonDecode(await rootBundle.loadString(
        'assets/web/folia_stage_ready.json'));
      return data is Map && data['available'] == true;
    } catch (_) {
      return false;
    }
  }

  @override
  State<OriginalLyricsWebHost> createState() => _OriginalLyricsWebHostState();
}

class _OriginalLyricsWebHostState extends State<OriginalLyricsWebHost>
    with WidgetsBindingObserver {
  WebViewController? _web;
  OriginalLyricsAssetServer? _assetServer;
  StreamSubscription<List<double>>? _spectrum;
  bool _ready = false, _failed = false, _hidden = false;
  List<LyricLine>? _sentLines;
  Md3LyricStageMode? _sentMode;
  String? _sentColor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.positionListenable?.addListener(_clock);
    _init();
  }

  Future<void> _init() async {
    if (!await OriginalLyricsWebHost.bundleAvailable() || !mounted) return;
    OriginalLyricsAssetServer? server;
    try {
      server = await OriginalLyricsAssetServer.start();
      if (!mounted) {
        await server.close();
        return;
      }
      _assetServer = server;
      final web = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..enableZoom(false)
        ..addJavaScriptChannel('MD3StageChannel',
            onMessageReceived: _onMessage)
        ..setNavigationDelegate(NavigationDelegate(
          onWebResourceError: (e) {
            if (e.isForMainFrame == true) _fail();
          },
          onNavigationRequest: (r) {
            final uri = Uri.tryParse(r.url);
            final accepted = uri != null &&
                uri.scheme == 'http' &&
                uri.host == '127.0.0.1' &&
                uri.port == server!.port;
            return accepted || r.url == 'about:blank'
                ? NavigationDecision.navigate : NavigationDecision.prevent;
          },
        ));
      _web = web;
      if (mounted) setState(() {});
      await web.loadRequest(server.entry);
      if (!mounted) return;
      _spectrum = SpectrumService.instance.spectrumStream.listen(_onSpectrum);
    } catch (_) { _fail(); }
  }

  void _fail() {
    if (!mounted) return;
    setState(() { _ready = false; _failed = true; });
    _spectrum?.cancel();
  }

  void _onMessage(JavaScriptMessage message) {
    if (!mounted) return;
    try {
      final m = jsonDecode(message.message);
      if (m is! Map) return;
      switch (m['type']) {
        case 'ready':
          if (!_ready && !_failed) {
            setState(() => _ready = true);
            _scene();
          }
        case 'seek':
          final pos = m['positionMs'];
          if (pos is num && pos.isFinite && pos >= 0 && pos <= 86400000) {
            widget.onSeek(Duration(milliseconds: pos.round()));
          }
        case 'error':
          _fail();
      }
    } catch (_) {}
  }

  static String modeId(Md3LyricStageMode mode) =>
      mode == Md3LyricStageMode.glow ? 'classic' : mode.name;

  static Map<String, Object?> serializeLine(LyricLine line) => {
    'startTime': line.startTime / 1000.0,
    'endTime': line.endTime / 1000.0,
    'fullText': line.text,
    'translation': line.translation,
    'romanization': line.roma,
    'agentId': line.agentId,
    'words': [
      for (final w in line.words)
        {'text': w.text, 'startTime': w.startTime / 1000.0,
         'endTime': (w.startTime + w.duration) / 1000.0},
    ],
  };

  static String colorHex(Color color) =>
      '#' + (color.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0');

  void _post(Map<String, Object?> message) {
    if (!_ready || _failed || _web == null || !mounted) return;
    // Encode twice; lyric content must never become executable JavaScript.
    final payload = jsonEncode(jsonEncode(message));
    unawaited(_web!.runJavaScript(
      'window.md3StageReceive && window.md3StageReceive(' + payload + ');',
    ).catchError((Object _) { _fail(); }));
  }

  void _scene() {
    if (!_ready || !mounted) return;
    final colors = Theme.of(context).colorScheme;
    _sentLines = widget.lines;
    _sentMode = widget.mode;
    _sentColor = colorHex(colors.primary);
    _post({
      'type': 'scene',
      'mode': modeId(widget.mode),
      'lines': widget.lines.map(serializeLine).toList(),
      'songTitle': widget.songTitle,
      'songArtist': widget.songArtist,
      'songAlbum': widget.songAlbum,
      'coverUrl': widget.coverUrl != null &&
          widget.coverUrl!.startsWith('https://')
          ? widget.coverUrl : null,
      'palette': {
        'backgroundColor': colorHex(colors.surface),
        'primaryColor': colorHex(colors.onSurface),
        'accentColor': colorHex(colors.primary),
        'secondaryColor': colorHex(colors.secondary),
      },
    });
    _clock();
  }

  void _clock() {
    if (!_ready || !mounted) return;
    final position = widget.positionListenable?.value ?? widget.position;
    final adjusted = widget.adaptPosition?.call(position) ?? position;
    _post({'type': 'clock', 'positionMs': adjusted.inMilliseconds.clamp(0, 86400000),
      'playing': widget.isPlaying && !_hidden});
  }

  void _onSpectrum(List<double> bands) {
    if (!_ready || bands.isEmpty || _hidden) return;
    double avg(int low, int high) {
      final end = high.clamp(0, bands.length);
      if (low >= end) return 0;
      var sum = 0.0;
      for (var i = low; i < end; i++) { sum += bands[i]; }
      return (sum / (end - low)).clamp(0.0, 1.0).toDouble();
    }
    final n = bands.length;
    _post({'type': 'audio', 'bands': [
      avg(0, (n * .12).ceil()),
      avg((n * .12).floor(), (n * .28).ceil()),
      avg((n * .28).floor(), (n * .51).ceil()),
      avg((n * .51).floor(), (n * .79).ceil()),
      avg((n * .79).floor(), n),
    ]});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scene();
      });
    }
  }

  @override
  void didUpdateWidget(covariant OriginalLyricsWebHost old) {
    super.didUpdateWidget(old);
    if (old.positionListenable != widget.positionListenable) {
      old.positionListenable?.removeListener(_clock);
      widget.positionListenable?.addListener(_clock);
    }
    if (_ready && (!identical(_sentLines, widget.lines) ||
        old.songTitle != widget.songTitle ||
        old.songArtist != widget.songArtist ||
        old.songAlbum != widget.songAlbum ||
        old.coverUrl != widget.coverUrl ||
        _sentMode != widget.mode ||
        _sentColor != colorHex(Theme.of(context).colorScheme.primary))) {
      _scene();
    } else { _clock(); }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _hidden = state != AppLifecycleState.resumed;
    _clock();
  }

  @override
  void dispose() {
    widget.positionListenable?.removeListener(_clock);
    WidgetsBinding.instance.removeObserver(this);
    _spectrum?.cancel();
    final server = _assetServer;
    if (server != null) unawaited(server.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || _web == null) return widget.fallback;
    return Stack(fit: StackFit.expand, children: [
      if (!_ready) widget.fallback,
      IgnorePointer(ignoring: !_ready,
        child: Opacity(opacity: _ready ? 1 : 0,
          child: WebViewWidget(controller: _web!))),
    ]);
  }
}
