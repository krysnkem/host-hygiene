// The Home screen: Storage, Memory, CPU, Alarms and Settings, one line of status each. Cockpit draws panels, Guided lets Hy ask, every other look draws the table.
import 'package:nocterm/nocterm.dart';
import 'home_model.dart';
import 'home_panels.dart';
import 'layout.dart';
import 'state.dart';
import 'ui.dart';

Color levelColor(Level l) => l == Level.crit ? Colors.red : l == Level.warn ? Colors.yellow : l == Level.ok ? Colors.green : Colors.white;

/// The rows for the state's reading ([Reading] null: nothing scanned yet).
List<HomeRow> rowsOf(AppState s) => homeRows(s.reading ?? Reading(), look: s.lookId, ignored: s.ignoredCount);

/// Hy's sentence for the Guided look.
String hySays(List<HomeRow> rows, {bool refreshing = false}) {
  final bad = [for (final r in rows) if (r.level == Level.warn || r.level == Level.crit) r.title];
  if (rows.first.status == 'not read yet' && refreshing) return 'Reading the machine. This takes a moment.';
  if (rows.first.status == 'not read yet') return 'I could not read the machine just now. Press r to try again.';
  if (bad.isEmpty) return 'Everything looks fine. What would you like to look at?';
  return '${bad.length == 1 ? '${bad.first} needs' : '${bad.take(bad.length - 1).join(', ')} and ${bad.last} need'} attention. What would you like to look at?';
}

class HomeView extends StatelessComponent {
  const HomeView({super.key, required this.s, required this.t});
  final AppState s;
  final Term t;

  @override
  Component build(BuildContext context) {
    final rows = rowsOf(s);
    if (s.lookId == 'cockpit' && t.cols >= 60 && t.rows >= 14) return HomePanels(rows: rows, sel: s.homeSel, t: t, note: s.homeNote, stamp: _stamp);
    if (s.lookId == 'guided' && t.rows >= 14) return _guided(rows);
    return _table(rows);
  }

  /// How fresh the numbers are: the last check stays up, marked old, while the machine is read again.
  String get _stamp => homeStamp(at: s.readingAt, refreshing: s.refreshing, scanning: s.scanning, now: DateTime.now());

  Component _hints() => keys(['${Gl.i.ud} move ${Gl.i.dot} enter open ${Gl.i.dot} s m c a g jump ${Gl.i.dot} r rescan ${Gl.i.dot} v look ${Gl.i.dot} q quit', '${Gl.i.ud} enter ${Gl.i.dot} s m c a g ${Gl.i.dot} r v q', 's m c a g r q'], t.inner);

  Component _table(List<HomeRow> rows) {
    final w = t.inner, g = Gl.i, r = s.reading;
    final head = r?.freeGb == null ? 'hh home' : 'hh home  free ${r!.freeGb} GiB${r.load == null ? '' : '  load ${r.load}'}';
    final stW = (w - 22).clamp(10, 60);
    return Padding(padding: EdgeInsets.symmetric(horizontal: 1), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      line(head, w, color: Colors.white, bold: true),
      for (var i = 0; i < rows.length; i++)
        Text(fit('${i == s.homeSel ? g.arrow : ' '} ${rows[i].key} ${rows[i].title.padRight(9)} ${fit(rows[i].status, stW).padRight(stW)} ${rows[i].word}', w), softWrap: false,
            style: TextStyle(color: i == s.homeSel ? Colors.black : levelColor(rows[i].level), backgroundColor: i == s.homeSel ? Colors.magenta : null, fontWeight: i == s.homeSel ? FontWeight.bold : null)),
      if (s.homeNote.isNotEmpty) line(s.homeNote, w, color: Colors.cyan),
      if (_stamp.isNotEmpty) line(_stamp, w, color: Colors.brightBlack),
      _hints(),
    ]));
  }

  Component _guided(List<HomeRow> rows) {
    final w = t.inner, g = Gl.i, bad = rows.any((r) => r.level == Level.warn || r.level == Level.crit);
    return Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!t.compact) SizedBox(height: 1),
      hyCard(g.face(bad ? 'tight' : 'calm'), bad ? Colors.yellow : Colors.green, wrapLines(hySays(rows, refreshing: s.refreshing), t.speechW), compact: t.compact),
      SizedBox(height: t.compact ? 0.0 : 1.0),
      for (var i = 0; i < rows.length; i++)
        Text(fit('  ${i == s.homeSel ? g.arrow : ' '} ${rows[i].title}: ${rows[i].status}', w), softWrap: false, style: TextStyle(color: i == s.homeSel ? Colors.black : levelColor(rows[i].level), backgroundColor: i == s.homeSel ? Colors.magenta : null, fontWeight: i == s.homeSel ? FontWeight.bold : null)),
      if (s.homeNote.isNotEmpty) line('  ${s.homeNote}', w, color: Colors.cyan),
      if (_stamp.isNotEmpty) line('  $_stamp', w, color: Colors.brightBlack),
      _hints(),
    ]));
  }
}

List<String> wrapLines(String text, int w) => [for (final sp in wrapSpans(text, w)) text.substring(sp[0], sp[1])];
