// The Memory and CPU screens: a reading, the running apps ranked by that resource (a browser's many processes are one row), and what you could close.
// Read-only by construction: nothing here can close, kill or signal a process. Ticking an app only adds up what closing it would free.
import 'dart:async';
import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'advice_text.dart';
import 'cockpit_parts.dart' show wrapTo;
import 'engine.dart';
import 'home_model.dart';
import 'layout.dart';
import 'perf_model.dart';
import 'resource_rows.dart';
import 'ui.dart';

class ResourceView extends StatefulComponent {
  const ResourceView({super.key, required this.script, required this.start, required this.onClose});
  final String script;
  final Resource start;
  final void Function() onClose;
  @override
  State<ResourceView> createState() => _ResourceViewState();
}

class _ResourceViewState extends State<ResourceView> {
  late Resource res = component.start == Resource.cpu ? Resource.cpu : Resource.memory;
  List<AppRow>? apps;
  Reading? rd;
  int cur = 0;
  final ticked = <String>{};
  bool summary = false;
  String note = '';
  int zi = 0;
  final eng = Engine();
  StreamSubscription<ProcessSignal>? winch;

  @override
  void initState() {
    super.initState();
    try { winch = ProcessSignal.sigwinch.watch().listen((_) => setState(() {})); } catch (_) {}
    _load();
  }

  @override
  void dispose() { winch?.cancel(); super.dispose(); }

  Future<void> _load() async {
    setState(() { apps = null; rd = null; });
    final r = await Future.wait([loadApps(component.script), Engine().reading()]);
    if (mounted) setState(() { apps = r[0] as List<AppRow>; rd = r[1] as Reading; cur = 0; });
  }

  static const _z = ['1h', '4h', '24h', 'tomorrow', 'off'];

  Future<void> _ignore(AppRow a) async {
    final err = await eng.setIgnored([...await eng.ignored(), a.name]);
    if (err != null) { if (mounted) setState(() => note = err); return; }
    ticked.remove(a.name);
    await _load();
    if (mounted) setState(() => note = '${a.name} is ignored: no more advice or alarm mentions. Settings lists it so you can restore it.');
  }

  Future<void> _snooze() async {
    final r = await eng.snooze(res, _z[zi % _z.length]); zi++;
    final fresh = await eng.reading();
    if (mounted) setState(() { rd = fresh; note = r; });
  }

  List<AppRow> get ranked => rankFor(res, apps ?? const []);

  bool _key(KeyboardEvent k) {
    final lk = k.logicalKey, rs = ranked, n = rs.length;
    if (lk == LogicalKey.escape || lk == LogicalKey.arrowLeft || lk == LogicalKey.keyQ || (k.isControlPressed && lk == LogicalKey.keyC)) { component.onClose(); return true; }
    if (lk == LogicalKey.keyR) { note = ''; _load(); return true; }
    if (lk == LogicalKey.tab || (lk == LogicalKey.keyM && res == Resource.cpu) || (lk == LogicalKey.keyC && res == Resource.memory)) { setState(() { res = res == Resource.cpu ? Resource.memory : Resource.cpu; cur = 0; summary = false; note = ''; }); return true; }
    if (lk == LogicalKey.keyZ) { _snooze(); return true; }
    if (lk == LogicalKey.keyY) { setState(() => summary = !summary); return true; }
    if (n == 0) return false;
    if (lk == LogicalKey.arrowDown || lk == LogicalKey.keyJ) { setState(() => cur = (cur + 1) % n); return true; }
    if (lk == LogicalKey.arrowUp || lk == LogicalKey.keyK) { setState(() => cur = (cur + n - 1) % n); return true; }
    if (lk == LogicalKey.keyI) { final a = rs[cur.clamp(0, n - 1)]; if (!a.system) _ignore(a); else setState(() => note = '${a.name} belongs to macOS; there is nothing to ignore or close.'); return true; }
    if (lk == LogicalKey.space) { final a = rs[cur.clamp(0, n - 1)]; if (!a.system) setState(() { if (!ticked.remove(a.name)) ticked.add(a.name); }); return true; }
    return false;
  }

  @override
  Component build(BuildContext context) {
    final t = Term(), g = Gl.i, w = t.inner, head = headerText(res, rd);
    Component frame(List<Component> kids) => Focusable(focused: true, onKeyEvent: _key, child: Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: kids)));
    final rs = apps == null ? null : ranked;
    if (rs == null) return frame([line(head, w, color: Colors.white, bold: true), line('${g.spin[DateTime.now().second % 10]} Reading the running apps', w, color: Colors.cyan)]);
    final at = rs.isEmpty ? 0 : cur.clamp(0, rs.length - 1), c = rs.isEmpty ? null : rs[at], on = [for (final a in rs) if (ticked.contains(a.name)) a];
    final sn = note.isNotEmpty ? note : snoozeText(res, rd), win = (t.rows - 9 - (sn.isNotEmpty ? 1 : 0)).clamp(1, 40), top = at >= win ? at - win + 1 : 0, nameW = (w - 36).clamp(10, 40);
    final lvl = rd?.levelFor(res) ?? Level.unknown;
    return frame([
      line(head, w, color: lvl == Level.crit ? Colors.red : lvl == Level.warn ? Colors.yellow : Colors.white, bold: true),
      if (rs.isEmpty) line('I could not read the process list just now. Press r to try again.', w, color: Colors.yellow)
      else ...[
        line('      #  ${'APP'.padRight(nameW)} PROCS      MEM   CPU  KIND', w, color: Colors.brightBlack),
        for (var i = top; i < rs.length && i < top + win; i++)
          Text(fit('${i == at ? g.arrow : ' '} ${rowText(rs[i], ticked.contains(rs[i].name), nameW, i)}', w), softWrap: false, style: TextStyle(color: i == at ? Colors.black : (rs[i].system ? Colors.brightBlack : Colors.white), backgroundColor: i == at ? Colors.magenta : null, fontWeight: i == at ? FontWeight.bold : null)),
        line(summary ? summaryText(res, on) : tallyText(res, on), w, color: Colors.cyan),
        if (sn.isNotEmpty) line(sn, w, color: Colors.yellow),
        if (t.rows >= 11) for (final l in wrapTo(directionsText(c), w, t.rows >= 14 ? 3 : 2)) line(l, w, color: c!.system ? Colors.yellow : Colors.green),
      ],
      keys(['${g.ud} move ${g.dot} space tick ${g.dot} i ignore ${g.dot} z snooze ${g.dot} y summary ${g.dot} tab ${res == Resource.cpu ? 'memory' : 'CPU'} ${g.dot} r rescan ${g.dot} esc back', '${g.ud} space i z y tab r esc', 'space tab esc'], w),
    ]);
  }
}

String summaryText(Resource r, List<AppRow> ticked) => summary(r, ticked);
