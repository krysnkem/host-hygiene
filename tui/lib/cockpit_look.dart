// Design A, the cockpit: a status line, two panes (list and detail, or stage status), and a footer with Hy's line, totals and keys.
import 'package:nocterm/nocterm.dart';
import 'cockpit_parts.dart';
import 'cockpit_stages.dart';
import 'engine.dart';
import 'layout.dart';
import 'look.dart';
import 'plain_look.dart';
import 'state.dart';
import 'ui.dart';

class CockpitLook extends Look {
  const CockpitLook();
  @override String get id => 'cockpit';
  @override String get name => 'Cockpit';
  @override int get minCols => 60;
  @override int get minRows => 16;

  @override
  int listRows(AppState s, Term t) => (Geo(t).hA - 2).clamp(1, 60);

  @override
  Component build(AppState s, Term t, Actions act) {
    final g = Geo(t), p = panesFor(s, t, g, act);
    final a = Pane(title: p.ta, w: g.wA, h: g.hA, hot: !p.hotB, rows: p.a), b = Pane(title: p.tb, w: g.wB, h: g.hB, hot: p.hotB, rows: p.b);
    return Padding(padding: EdgeInsets.symmetric(horizontal: 1), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header(s, g.w),
      if (g.stacked) Column(children: [a, b]) else Row(crossAxisAlignment: CrossAxisAlignment.start, children: [a, SizedBox(width: 1), b]),
      if (g.totals) rowOf(_totals(s, g, p), g.w),
      ..._hy(s, g),
      rowOf([Seg(tier(tagged(_keys(s), lookKey(s)), g.w), fg: Colors.brightBlack)], g.w),
    ]));
  }
}

Component _header(AppState s, int w) {
  final dot = Gl.i.utf ? '●' : '*', c = s.mood == 'stop' ? Colors.red : (s.mood == 'tight' ? Colors.yellow : Colors.green);
  final free = s.g['free_gb'] == null ? '' : tier(['free ${s.g['free_gb']} GiB  ${Gl.i.dot}  load ${s.g['load'] ?? '?'}', 'free ${s.g['free_gb']} GiB'], w ~/ 2);
  final name = stageNames[s.stage.index];
  return rowOf([Seg('$dot ', fg: c, bold: true), const Seg('host-hygiene', fg: Colors.white, bold: true), Seg('  $name', fg: Colors.magenta, bold: true), Seg('   $free', fg: Colors.brightBlack)], w);
}

List<Seg> _totals(AppState s, Geo g, PaneSet p) {
  final n = s.items.where((i) => i.on).length, d = Gl.i, st = s.stage;
  final end = (s.top + g.hA - 2).clamp(0, s.items.length), more = '${s.top > 0 ? '${d.up} more above ' : ''}${end < s.items.length ? '${d.down} more below' : ''}';
  final txt = st == Stage.pick ? tier(['Selected: $n item(s), about ${size(s.selectedKb)}${more.isEmpty ? '' : '   $more'}', '$n selected, ${size(s.selectedKb)}'], g.w)
      : st == Stage.confirm ? 'Selected: ${s.chosen.length} item(s), about ${size(s.chosen.fold(0, (a, i) => a + i.kb))}'
      : st == Stage.work ? 'Freed so far: ${size(s.freedKb)}' : st == Stage.done && s.ran > 0 ? 'Freed: ${s.freed}' : '';
  return [Seg(txt, fg: Colors.magenta, bold: true)];
}

List<Component> _hy(AppState s, Geo g) {
  final f = s.stage == Stage.work ? Gl.i.face('work${(s.tick ~/ 6) % 4}') : s.stage == Stage.done ? Gl.i.face('done') : s.mood == 'stop' ? Gl.i.face('stop') : s.mood == 'tight' ? Gl.i.face('tight') : Gl.i.face(s.tick % 70 < 3 ? 'blink' : 'calm');
  final lines = g.hy == 1 ? spokenLines(s, 400, last: 1) : spokenLines(s, g.w - 8, last: 2);
  final fc = s.mood == 'stop' ? Colors.red : Colors.yellow;
  return [for (var i = 0; i < g.hy; i++) rowOf([Seg(i == 0 ? '${f.padRight(8)}' : ' ' * 8, fg: fc, bold: true), Seg(i < lines.length ? lines[i] : '', fg: Colors.cyan)], g.w)];
}

List<String> _keys(AppState s) {
  final d = Gl.i, st = s.stage;
  switch (st) {
    case Stage.pick: return ['${d.ud} move ${d.dot} space tick ${d.dot} PgUp/PgDn ${d.dot} Home/End ${d.dot} s safe ${d.dot} f ask-first ${d.dot} a all ${d.dot} n none ${d.dot} enter continue ${d.dot} q quit', '${d.ud} ${d.dot} space ${d.dot} PgUp/Dn ${d.dot} s safe ${d.dot} f ask ${d.dot} a all ${d.dot} n none ${d.dot} enter ${d.dot} q quit', '${d.ud} space s a f n enter q'];
    case Stage.confirm: return ['${d.lr} move ${d.dot} enter choose ${d.dot} esc back ${d.dot} q quit', '${d.lr} enter esc q'];
    case Stage.limits: return ['${d.lr} move ${d.dot} enter choose', '${d.lr} enter'];
    case Stage.done: return doneKeys();
    default: return ['working... keys are paused until it finishes', 'working...'];
  }
}
