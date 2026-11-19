// Design D, the guided journey: a stepper, the mascot Hy, and one body per stage.
import 'package:nocterm/nocterm.dart';
import 'layout.dart';
import 'look.dart';
import 'state.dart';
import 'ui.dart';
import 'views.dart';

class GuidedLook extends Look {
  const GuidedLook();
  @override String get id => 'guided';
  @override String get name => 'Guided journey';
  @override int get minCols => Term.minCols;
  @override int get minRows => Term.minRows;

  @override
  int listRows(AppState s, Term t) => (t.rows - guidedHead(s, t) - 5).clamp(1, 60);

  @override
  Component build(AppState s, Term t, Actions act) => Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _body(s, t, act)));

  List<Component> _body(AppState s, Term t, Actions act) {
    final spin = Gl.i.spin[s.tick % 10], gap = t.compact ? 0.0 : 1.0, st = s.stage, head = guidedHead(s, t);
    final step = st == Stage.look || st == Stage.limits ? 0 : st == Stage.pick ? 1 : st == Stage.confirm ? 2 : 3;
    final out = <Component>[
      if (!t.compact) SizedBox(height: 1),
      if (!t.tiny) stepper(step, narrow: t.narrow),
      if (!t.compact) SizedBox(height: 1),
      if (_showHy(s, t)) hyCard(_face(s), s.mood == 'stop' ? Colors.red : Colors.yellow, _spoken(s, t), compact: t.compact),
      SizedBox(height: gap),
    ];
    if (st == Stage.look) out.add(line('  $spin Looking around your machine', t.inner, color: Colors.cyan));
    if (st == Stage.limits && s.speechDone) out.add(LimitsView(t: t, sel: s.sel, g: s.g));
    if (st == Stage.pick) out.add(PickView(t: t, items: s.items, cur: s.cur, top: s.top, win: listRows(s, t), onTap: act.tap, tag: lookKey(s)));
    if (st == Stage.confirm) {
      final fixed = 4 + (s.chosen.any((i) => !i.safe) ? 1 : 0) + (t.compact ? 0 : 2) + 1;
      out.add(ConfirmView(t: t, chosen: s.chosen, cap: (t.rows - head - fixed).clamp(1, 12), sel: s.sel));
    }
    if (st == Stage.work) out.add(WorkView(t: t, spin: spin, total: s.total, finished: s.finished, current: s.current, results: s.results, cap: (t.rows - head - 2).clamp(0, 5)));
    if (st == Stage.done) out.add(DoneView(t: t, ran: s.ran, before: s.freeBefore, after: s.freeAfter, manual: s.items.where((i) => !i.supported).length, problems: s.problems));
    return out;
  }
}

bool _showHy(AppState s, Term t) => !t.tiny || s.stage == Stage.look || s.stage == Stage.limits || s.stage == Stage.done;
int _spokenN(AppState s, Term t) => (s.stage == Stage.done || t.rows >= 14) ? 2 : 1;
int _total(AppState s, Term t) => s.lines.fold(0, (n, l) => n + wrapSpans(l, t.speechW).length).clamp(1, 8);
/// Rows the chrome above the body takes, so the list gets the rest.
int guidedHead(AppState s, Term t) => t.tiny ? (_showHy(s, t) ? _spokenN(s, t) : 0) : (t.compact ? 1 + _spokenN(s, t) : 8 + _total(s, t));
List<String> _spoken(AppState s, Term t) => t.compact ? spokenLines(s, t.speechW, last: _spokenN(s, t)) : spokenLines(s, t.speechW, pad: _total(s, t));

String _face(AppState s) {
  final f = Gl.i.face;
  if (s.stage == Stage.work) return f('work${(s.tick ~/ 6) % 4}');
  if (s.stage == Stage.done) return f('done');
  if (s.mood == 'stop') return f('stop');
  if (s.mood == 'tight') return f('tight');
  return f((s.tick % 70 < 3) ? 'blink' : 'calm');
}
