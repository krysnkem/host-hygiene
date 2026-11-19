// The plain look: no mascot, no stepper, one list. The documented fallback when the chosen look does not fit the terminal (or ui=plain).
import 'package:nocterm/nocterm.dart';
import 'layout.dart';
import 'look.dart';
import 'state.dart';
import 'ui.dart';
import 'views.dart';

class PlainLook extends Look {
  const PlainLook({this.hint = ''});
  /// Why this look is on screen when it was not asked for; shown as the first line (rows >= 8 only).
  final String hint;
  @override String get id => 'plain';
  @override String get name => 'Plain list';
  @override int get minCols => Term.minCols;
  @override int get minRows => Term.minRows;
  @override bool get speaks => false;

  bool _head(Term t) => t.rows >= 8;
  @override
  int listRows(AppState s, Term t) => (t.rows - (_head(t) ? 1 : 0) - 5).clamp(1, 60);

  @override
  Component build(AppState s, Term t, Actions act) {
    final st = s.stage, spin = Gl.i.spin[s.tick % 10], head = _head(t) ? 1 : 0;
    return Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (head == 1) line(hint.isEmpty ? 'host-hygiene  ${stageNames[st.index]}' : hint, t.inner, color: Colors.brightBlack),
      if (st == Stage.look) line('  $spin Looking around your machine', t.inner, color: Colors.cyan),
      if (st == Stage.limits) LimitsView(t: t, sel: s.sel, g: s.g),
      if (st == Stage.pick) PickView(t: t, items: s.items, cur: s.cur, top: s.top, win: listRows(s, t), onTap: act.tap),
      if (st == Stage.confirm) ConfirmView(t: t, chosen: s.chosen, cap: (t.rows - head - 8).clamp(1, 12), sel: s.sel),
      if (st == Stage.work) WorkView(t: t, spin: spin, total: s.total, finished: s.finished, current: s.current, results: s.results, cap: (t.rows - head - 2).clamp(0, 5)),
      if (st == Stage.done) DoneView(t: t, ran: s.ran, before: s.freeBefore, after: s.freeAfter, manual: s.items.where((i) => !i.supported).length, problems: s.problems),
    ]));
  }
}

const stageNames = ['Looking', 'Limits', 'Pick', 'Confirm', 'Working', 'Done'];
