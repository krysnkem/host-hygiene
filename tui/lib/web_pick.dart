// The browser chooser: one short-lived server on 127.0.0.1 that serves one embedded page and accepts one POST. No file is ever read from disk by a request.
// Event-driven: a listening socket and two one-shot timers, nothing polls. It ends on the first valid save, a cancel, or a timeout, and then the port is closed.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'web_page.dart';

enum WebEnd { saved, cancelled, noRequest, idle, launchFailed }

class WebResult {
  const WebResult(this.end, {this.look, this.msg = ''});
  final WebEnd end;
  final String? look;
  final String msg;
}

/// How to open a page: [cmd] is an executable that takes the URL as its only argument, or null with [why] saying plainly why not.
class Browser {
  const Browser(this.cmd, this.why);
  final String? cmd;
  final String why;
}

String? _which(String name, Map<String, String> env) {
  for (final d in (env['PATH'] ?? '').split(':')) {
    if (d.isEmpty) continue;
    final f = File('$d/$name');
    try { if (f.existsSync() && (f.statSync().mode & 0x49) != 0) return f.path; } catch (_) {}
  }
  return null;
}

/// HH_BROWSER_CMD (test hook, wins) -> macOS `open` -> Linux $BROWSER / xdg-open. Never over SSH and never without a graphical session.
Future<Browser> findBrowser(Map<String, String> env) async {
  final hook = env['HH_BROWSER_CMD'] ?? '';
  if (hook.isNotEmpty) return Browser(hook, '');
  if ((env['SSH_CONNECTION'] ?? '').isNotEmpty || (env['SSH_TTY'] ?? '').isNotEmpty) return const Browser(null, 'this is an SSH session, so a browser would open on the wrong machine');
  if (Platform.isMacOS) {
    final open = _which('open', env);
    if (open == null) return const Browser(null, "there is no 'open' command");
    try {
      final r = await Process.run('launchctl', ['managername'], environment: env).timeout(const Duration(seconds: 3));
      if ((r.stdout as String).trim() != 'Aqua') return const Browser(null, 'there is no graphical login session');
    } catch (_) { /* cannot tell: trust `open` */ }
    return Browser(open, '');
  }
  if ((env['DISPLAY'] ?? '').isEmpty && (env['WAYLAND_DISPLAY'] ?? '').isEmpty) return const Browser(null, 'there is no graphical session');
  final b = (env['BROWSER'] ?? '').isNotEmpty ? _which(env['BROWSER']!, env) : null;
  final x = b ?? _which('xdg-open', env);
  return x == null ? const Browser(null, 'no browser was found (xdg-open or BROWSER)') : Browser(x, '');
}

/// HH_WEB_TIMEOUTS="FIRST,IDLE" in seconds (tests shorten it); default 60 s for the page to be requested, 300 s idle after that.
(Duration, Duration) webTimeouts(Map<String, String> env) {
  final m = RegExp(r'^(\d+(?:\.\d+)?),(\d+(?:\.\d+)?)$').firstMatch(env['HH_WEB_TIMEOUTS'] ?? '');
  Duration d(String s) => Duration(milliseconds: (double.parse(s) * 1000).round());
  return m == null ? (const Duration(seconds: 60), const Duration(seconds: 300)) : (d(m.group(1)!), d(m.group(2)!));
}

class WebPick {
  WebPick({required this.current, required this.allowed, required this.save, Map<String, String>? env}) : env = env ?? Platform.environment;
  final String current;
  /// The ids a save may name: the five designs, never plain.
  final List<String> allowed;
  /// Writes the choice through `config set ui`; false when that failed.
  final Future<bool> Function(String id) save;
  final Map<String, String> env;
  static const maxBody = 1024;

  final _done = Completer<WebResult>();
  HttpServer? _srv;
  Timer? _first, _idle;
  late final String _token = _newToken();
  late final (Duration, Duration) _tm = webTimeouts(env);

  static String _newToken() { final r = Random.secure(); return List.generate(24, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join(); }

  void cancel() => _finish(const WebResult(WebEnd.cancelled));

  void _finish(WebResult r) {
    if (_done.isCompleted) return;
    _first?.cancel(); _idle?.cancel();
    _srv?.close(force: true);
    _done.complete(r);
  }

  /// Binds, opens the page with [b] and completes when the server has ended. The port is closed by then.
  Future<WebResult> run(Browser b) async {
    try { _srv = await HttpServer.bind(InternetAddress.loopbackIPv4, 0); } catch (e) { return WebResult(WebEnd.launchFailed, msg: 'could not open a local port ($e)'); }
    final port = _srv!.port;
    _srv!.listen((q) => _handle(q, port).catchError((_) { try { q.response.statusCode = 500; q.response.close(); } catch (_) {} }));
    _first = Timer(_tm.$1, () => _finish(WebResult(WebEnd.noRequest, msg: 'the browser page was not opened within ${_secs(_tm.$1)}')));
    final url = 'http://127.0.0.1:$port/$_token/';
    () async {
      try {
        final r = await Process.run(b.cmd!, [url]).timeout(const Duration(seconds: 15));
        if (r.exitCode != 0) _finish(WebResult(WebEnd.launchFailed, msg: 'the browser command failed (exit ${r.exitCode})'));
      } catch (e) { _finish(WebResult(WebEnd.launchFailed, msg: 'the browser command could not run')); }
    }();
    return _done.future;
  }

  static String _secs(Duration d) => d.inMilliseconds % 1000 == 0 ? '${d.inSeconds} s' : '${(d.inMilliseconds / 1000).toStringAsFixed(1)} s';

  bool _same(String a, String b) {
    if (a.length != b.length) return false;
    var x = 0;
    for (var i = 0; i < a.length; i++) { x |= a.codeUnitAt(i) ^ b.codeUnitAt(i); }
    return x == 0;
  }

  Future<void> _reply(HttpRequest q, int code, String body, {String type = 'text/plain; charset=utf-8'}) async {
    final h = q.response.headers;
    q.response.statusCode = code;
    h.set('Content-Type', type); h.set('Cache-Control', 'no-store'); h.set('X-Content-Type-Options', 'nosniff'); h.set('Referrer-Policy', 'no-referrer'); h.set('Cross-Origin-Resource-Policy', 'same-origin');
    if (type.startsWith('text/html')) h.set('Content-Security-Policy', "default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'");
    if (code == 405) h.set('Allow', 'GET, POST');
    q.response.write(body);
    await q.response.close();
  }

  Future<void> _handle(HttpRequest q, int port) async {
    // DNS-rebinding and CSRF: the Host must be exactly this server and an Origin, when sent, must be this page.
    if (q.headers.value('host') != '127.0.0.1:$port') return _reply(q, 403, 'forbidden');
    final origin = q.headers.value('origin');
    if (origin != null && origin != 'http://127.0.0.1:$port') return _reply(q, 403, 'forbidden');
    if (q.method != 'GET' && q.method != 'POST') return _reply(q, 405, 'method not allowed');
    final parts = q.uri.path.split('/');   // '/<token>/' -> ['', token, '']
    if (parts.length < 2 || !_same(parts[1], _token)) return _reply(q, 403, 'forbidden');
    final rest = parts.sublist(2).join('/');
    _idle?.cancel(); _idle = Timer(_tm.$2, () => _finish(WebResult(WebEnd.idle, msg: 'nothing was chosen within ${_secs(_tm.$2)}')));
    if (q.method == 'GET' && rest == '') {
      _first?.cancel();
      return _reply(q, 200, choosePage.replaceFirst('__CURRENT__', allowed.contains(current) ? current : ''), type: 'text/html; charset=utf-8');
    }
    if (q.method == 'POST' && rest == 'save') return _save(q);
    return _reply(q, 404, 'not found');
  }

  Future<void> _save(HttpRequest q) async {
    if (!(q.headers.contentType?.mimeType == 'application/json')) return _reply(q, 400, 'expected JSON');
    if (q.contentLength < 0 || q.contentLength > maxBody) return _reply(q, 413, 'too large');
    final bytes = <int>[];
    await for (final c in q) { bytes.addAll(c); if (bytes.length > maxBody) return _reply(q, 413, 'too large'); }
    Object? j;
    try { j = jsonDecode(utf8.decode(bytes)); } catch (_) { return _reply(q, 400, 'bad JSON'); }
    if (j is! Map || j.length != 2 || j['look'] is! String || j['token'] is! String) return _reply(q, 400, 'bad request');
    if (!_same(j['token'] as String, _token)) return _reply(q, 403, 'forbidden');
    final id = j['look'] as String;
    if (!allowed.contains(id)) return _reply(q, 400, 'unknown look');
    if (!await save(id)) return _reply(q, 500, 'could not save');
    await _reply(q, 200, 'OK');
    _finish(WebResult(WebEnd.saved, look: id));
  }
}
