import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Serves only allowlisted bundled visualizer files on 127.0.0.1.
/// The loopback origin allows Chromium ES modules / workers / WebGL to work
/// without enabling unsafe file:// cross-origin access or a remote server.
class OriginalLyricsAssetServer {
  OriginalLyricsAssetServer._(this._server, this._files);

  final HttpServer _server;
  final Set<String> _files;

  int get port => _server.port;
  Uri get entry => Uri(scheme: 'http', host: '127.0.0.1',
      port: port, path: '/folia_stage.html');

  static Future<OriginalLyricsAssetServer> start() async {
    final manifest = jsonDecode(await rootBundle.loadString(
      'assets/web/folia_stage_ready.json',
    ));
    if (manifest is! Map || manifest['available'] != true ||
        manifest['files'] is! List) {
      throw const FormatException('Offline visualizer assets not built');
    }
    final filenames = <String>{};
    for (final item in manifest['files'] as List) {
      if (item is! String ||
          item.isEmpty || item.contains('/') ||
          item.contains('\\') || item.contains('..')) {
        throw const FormatException('Invalid bundled visualizer asset name');
      }
      filenames.add(item);
    }
    if (!filenames.contains('folia_stage.html') ||
        !filenames.contains('folia-stage.js')) {
      throw const FormatException('Missing original renderer output');
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final service = OriginalLyricsAssetServer._(server, filenames);
    server.listen(service._serve);
    return service;
  }

  static String _mime(String name) {
    if (name.endsWith('.html')) return 'text/html; charset=utf-8';
    if (name.endsWith('.js') || name.endsWith('.mjs')) {
      return 'text/javascript; charset=utf-8';
    }
    if (name.endsWith('.css')) return 'text/css; charset=utf-8';
    if (name.endsWith('.json')) return 'application/json; charset=utf-8';
    if (name.endsWith('.wasm')) return 'application/wasm';
    if (name.endsWith('.svg')) return 'image/svg+xml';
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.woff2')) return 'font/woff2';
    if (name.endsWith('.woff')) return 'font/woff';
    return 'application/octet-stream';
  }

  Future<void> _serve(HttpRequest request) async {
    final response = request.response;
    try {
      if (request.method != 'GET' && request.method != 'HEAD') {
        response.statusCode = HttpStatus.methodNotAllowed;
        return;
      }
      final segments = request.uri.pathSegments;
      if (segments.length != 1) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      final file = segments.single;
      if (!_files.contains(file)) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      final asset = await rootBundle.load('assets/web/' + file);
      response.headers.contentType = ContentType.parse(_mime(file));
      response.headers.set('Cache-Control', 'private, max-age=86400');
      response.headers.set('X-Content-Type-Options', 'nosniff');
      response.headers.set('Access-Control-Allow-Origin',
          'http://127.0.0.1:' + port.toString());
      if (request.method == 'GET') {
        response.add(asset.buffer.asUint8List(
          asset.offsetInBytes, asset.lengthInBytes));
      }
    } catch (_) {
      response.statusCode = HttpStatus.internalServerError;
    } finally {
      await response.close();
    }
  }

  Future<void> close() => _server.close(force: true);
}
