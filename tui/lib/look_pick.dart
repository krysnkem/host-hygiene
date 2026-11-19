// The look chooser: a list of the five designs with a small picture of the highlighted one, plus "open in the browser".
// One component for three uses: `hh look` (standalone), inside the running TUI (the L key) and the first-run question.
import 'dart:async';
import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'engine.dart';
import 'layout.dart';
import 'look.dart';
import 'look_previews.dart';
import 'ui.dart';
import 'web_pick.dart';

enum _Kind { browser, here, keep, look }

class _Opt {
  const _Opt(this.kind, this.label, [this.look]);
  final _Kind kind;
  final String label;
  final Look? look;
}

class LookPicker extends StatefulComponent {
  const LookPicker({super.key, required this.current, required this.first, required this.startWeb, required this.onDone});
  /// The look in force now (marked in the list).
  final String current;
  /// The first-run question: browser / here / keep the default.
  final bool first, startWeb;
  /// Called once: the id that was saved, or null when nothing changed.
  final void Function(String? saved) onDone;
  @override
  State<LookPicker> createState() => _LookPickerState();
}

class _LookPickerState extends State<LookPicker> {
  final eng = Engine();
  Browser? browser;
  WebPick? web;
  bool here = false, finished = false;
  int cur = 0;
  String note = '';
  StreamSubscription<ProcessSignal>? winch;

  /// The five designs, in the order the `v` key cycles them (plain is the automatic fallback and is not offered).
  static final designs = cycle;

  @override
  void initState() {
    super.initState();
    try { winch = ProcessSignal.sigwinch.watch().listen((_) => setState(() {})); } catch (_) {}
    findBrowser(Platform.environment).then((b) {
      if (!mounted) return;
      setState(() { browser = b; if (component.startWeb) { if (b.cmd != null) { _web(); } else { note = 'No browser: ${b.why}. Choose here.'; here = true; } } });
    });
  }

  @override
  void dispose() { winch?.cancel(); web?.cancel(); super.dispose(); }

  bool get _asking => component.first && !here;
  bool get _hasBrowser => browser?.cmd != null;

  List<_Opt> get opts => [
        if (_hasBrowser) const _Opt(_Kind.browser, 'Open in the browser'),
        if (_asking) ...const [_Opt(_Kind.here, 'Choose here, in the terminal'), _Opt(_Kind.keep, 'Keep the default (Guided journey)')]
        else ...[for (final l in designs) _Opt(_Kind.look, '${l.name.padRight(15)} ${l.minCols}x${l.minRows}', l)],
      ];

  void _finish(String? id) { if (finished) return; finished = true; component.onDone(id); }

  Future<void> _web() async {
    final w = WebPick(current: component.current, allowed: [for (final l in designs) l.id], save: eng.setUi);
    setState(() { web = w; note = ''; });
    final r = await w.run(browser!);
    if (!mounted) return;
    if (r.end == WebEnd.saved) { _finish(r.look); return; }
    setState(() { web = null; here = true; cur = 0; note = r.end == WebEnd.cancelled ? '' : 'Browser: ${r.msg}. Choose here instead.'; });
  }

  Future<void> _save(String id) async {
    final ok = await eng.setUi(id);
    if (!mounted) return;
    if (ok) { _finish(id); } else { setState(() => note = 'Could not save the look.'); }
  }

  void _enter() {
    final o = opts[cur.clamp(0, opts.length - 1)];
    switch (o.kind) {
      case _Kind.browser: _web();
      case _Kind.here: setState(() { here = true; cur = _index(component.current); });
      case _Kind.keep: _save('guided');
      case _Kind.look: _save(o.look!.id);
    }
  }

  int _index(String id) { final i = opts.indexWhere((o) => o.look?.id == id); return i < 0 ? 0 : i; }

  bool _key(KeyboardEvent k) {
    final lk = k.logicalKey, n = opts.length;
    if (k.isControlPressed && lk == LogicalKey.keyC) { if (web != null) { web!.cancel(); } else { _finish(null); } return true; }
    if (web != null) { if (lk == LogicalKey.escape) { web!.cancel(); } return true; }
    if (lk == LogicalKey.escape || lk == LogicalKey.keyQ) { _finish(null); return true; }
    if (lk == LogicalKey.arrowDown || lk == LogicalKey.keyJ) { setState(() { cur = (cur + 1) % n; note = ''; }); return true; }
    if (lk == LogicalKey.arrowUp || lk == LogicalKey.keyK) { setState(() { cur = (cur + n - 1) % n; note = ''; }); return true; }
    if (lk == LogicalKey.home) { setState(() => cur = 0); return true; }
    if (lk == LogicalKey.end) { setState(() => cur = n - 1); return true; }
    if (lk == LogicalKey.enter) { _enter(); return true; }
    return false;
  }

  @override
  Component build(BuildContext context) {
    final t = Term();
    if (browser == null) return Focusable(focused: true, onKeyEvent: _key, child: Text(''));
    if (web != null) return Focusable(focused: true, onKeyEvent: _key, child: WaitingView(t: t));
    final os = opts, at = cur.clamp(0, os.length - 1), o = os[at];
    final showPic = o.look != null && t.rows >= 24 && t.cols >= 50;
    final head = _asking ? 'Choose how I should look: in the browser, or here?' : 'Choose a look  (now: ${lookFor(component.current).name})';
    final extra = (t.rows >= 9 ? 1 : 0) + (note.isNotEmpty && t.rows >= 10 ? 1 : 0);
    final win = showPic ? os.length : (t.rows - 2 - extra - (t.rows >= 9 ? 1 : 0)).clamp(1, os.length);
    final top = at >= win ? at - win + 1 : 0;
    final info = o.look != null ? '${blurbs[o.look!.id]}' : switch (o.kind) {
      _Kind.browser => 'Shows all five designs as pictures; nothing is scanned.',
      _Kind.here => 'Pick from a list in this window.',
      _ => 'Guided journey, the default. Ask me again later with the L key.',
    };
    return Focusable(focused: true, onKeyEvent: _key, child: Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      line(head, t.inner, color: Colors.white, bold: true),
      for (var i = top; i < top + win; i++)
        GestureDetector(onTap: () { setState(() => cur = i); _enter(); }, child: Text(
          fit('${i == at ? Gl.i.arrow : ' '} ${os[i].label}${os[i].look?.id == component.current ? '   (current)' : ''}', t.inner),
          softWrap: false, style: TextStyle(color: i == at ? Colors.black : Colors.white, backgroundColor: i == at ? Colors.magenta : null, fontWeight: i == at ? FontWeight.bold : null))),
      if (showPic) ...[SizedBox(height: 1), LookPreview(id: o.look!.id, face: Gl.i.face('calm'), w: t.inner)],
      if (t.rows >= 9) line(info, t.inner, color: Colors.cyan),
      if (note.isNotEmpty && t.rows >= 10) line(note, t.inner, color: Colors.yellow),
      keys(['${Gl.i.ud} move ${Gl.i.dot} enter choose ${Gl.i.dot} esc ${_asking ? 'ask me later' : 'cancel'}', '${Gl.i.ud} enter ${Gl.i.dot} esc', 'enter esc'], t.inner),
    ])));
  }
}

/// Shown while the browser page is open.
class WaitingView extends StatelessComponent {
  const WaitingView({super.key, required this.t});
  final Term t;
  @override
  Component build(BuildContext context) => Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tier(['Waiting for your choice in the browser... (Esc to choose here instead)', 'Waiting for your choice in the browser... (Esc: here)', 'Waiting for the browser... (Esc: here)'], t.inner), softWrap: false, style: TextStyle(color: Colors.cyan)),
        if (t.rows >= 8) line('The page is served only to this computer and closes itself when you save.', t.inner, color: Colors.brightBlack),
      ]));
}
