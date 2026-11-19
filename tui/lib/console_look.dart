// Design E, the command console: a dense sortable table, a machine summary on top, a ':' command line at the bottom. Needs the Look.onKey hook (see look.dart).
import 'package:nocterm/nocterm.dart';
import 'console_cmd.dart';
import 'console_keys.dart';
import 'console_parts.dart';
import 'layout.dart';
import 'look.dart';
import 'state.dart';
import 'ui.dart';
import 'views.dart';

class ConsoleLook extends Look {
  const ConsoleLook();
  @override String get id => 'console';
  @override String get name => 'Console';
  @override int get minCols => 50;
  @override int get minRows => 10;
  @override bool get speaks => false;

  /// Header, column titles, command line and key hints take 4 rows; the table gets the rest.
  @override
  int listRows(AppState s, Term t) => (t.rows - 4).clamp(1, 500);

  @override
  bool onKey(AppState s, KeyboardEvent k, void Function(void Function()) redraw) => consoleKey(s, k, redraw, listRows(s, Term()));

  @override
  Component build(AppState s, Term t, Actions act) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ConsoleHeader(s: s, t: t),
        if (s.stage == Stage.pick) ..._pick(s, t, act) else Padding(padding: EdgeInsets.symmetric(horizontal: 1), child: _stage(s, t)),
      ]);

  List<Component> _pick(AppState s, Term t, Actions act) {
    final win = listRows(s, t), vis = visibleIdx(s.items, cm.filter), pos = visPos(vis, s.cur), cur = pos < 0 ? -1 : vis[pos];
    if (pos >= cm.vtop + win) cm.vtop = pos - win + 1;
    if (pos < cm.vtop) cm.vtop = pos < 0 ? 0 : pos;
    cm.vtop = cm.vtop.clamp(0, (vis.length - win).clamp(0, vis.length));
    final g = Gl.i, d = g.dot;
    return [
      cm.help ? ConsoleHelp(t: t, win: win + 1) : ConsoleTable(items: s.items, vis: vis, plan: ColPlan(t.cols, s.items), cur: cur, top: cm.vtop, win: win, onTap: act.tap),
      ConsoleCmdLine(t: t, item: cur < 0 ? null : s.items[cur], pos: pos, n: vis.length),
      keys([
        '${g.ud} move $d space tick $d s safe $d f ask $d a all $d n none $d z c p sort $d / filter $d : command $d enter go $d q quit',
        '${g.ud} $d space $d s f a n $d z c p sort $d / $d : cmd $d enter go $d q quit',
        '${g.ud} space $d s f a n $d zcp / : $d enter $d q',
        'space s f a n zcp / : enter q',
      ], t.cols - 1, tag: lookKey(s)),
    ];
  }

  Component _stage(AppState s, Term t) {
    final spin = Gl.i.spin[s.tick % 10], st = s.stage, w = t.cols - 2;
    return switch (st) {
      Stage.look => line('$spin scanning this machine', w, color: Colors.cyan),
      Stage.limits => LimitsView(t: t, sel: s.sel, g: s.g),
      Stage.confirm => ConfirmView(t: t, chosen: s.chosen, cap: (t.rows - 9).clamp(1, 12), sel: s.sel),
      Stage.work => WorkView(t: t, spin: spin, total: s.total, finished: s.finished, current: s.current, results: s.results, cap: (t.rows - 3).clamp(0, 5)),
      _ => DoneView(t: t, ran: s.ran, before: s.freeBefore, after: s.freeAfter, manual: s.items.where((i) => !i.supported).length, problems: s.problems),
    };
  }
}
