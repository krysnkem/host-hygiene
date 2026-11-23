// The Cockpit's Home: three resource panels side by side, then Alarms and Settings.
import 'package:nocterm/nocterm.dart';
import 'cockpit_parts.dart';
import 'home_model.dart';
import 'home_view.dart' show levelColor;
import 'layout.dart';
import 'ui.dart';

class HomePanels extends StatelessComponent {
  const HomePanels({super.key, required this.rows, required this.sel, required this.t, required this.note, this.stamp = ''});
  final List<HomeRow> rows;
  final int sel;
  final Term t;
  final String note, stamp;

  Pane _pane(int i, int w, int h) {
    final r = rows[i], parts = r.brief.isNotEmpty ? r.brief : r.status.split(', ');
    return Pane(title: '${r.title} [${r.key}]', w: w, h: h, hot: i == sel, rows: [
      for (final p in parts.take(h - 2)) Ln([Seg(p, fg: i == sel ? Colors.white : Colors.brightBlack)]),
      if (r.word.isNotEmpty && parts.length < h - 2) Ln([Seg(r.word, fg: levelColor(r.level), bold: true)]),
    ]);
  }

  @override
  Component build(BuildContext context) {
    final w = t.cols - 2, third = (w - 2) ~/ 3, last = w - 2 * third - 2, big = t.rows >= 18 ? 6 : 5, small = 4;
    return Padding(padding: EdgeInsets.symmetric(horizontal: 1), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      rowOf([const Seg('● ', fg: Colors.green, bold: true), const Seg('host-hygiene', fg: Colors.white, bold: true), const Seg('  Home', fg: Colors.magenta, bold: true)], w),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [_pane(0, third, big), SizedBox(width: 1), _pane(1, third, big), SizedBox(width: 1), _pane(2, last, big)]),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [_pane(3, (w - 1) ~/ 2, small), SizedBox(width: 1), _pane(4, w - 1 - (w - 1) ~/ 2, small)]),
      if (note.isNotEmpty) line(note, w, color: Colors.cyan),
      if (stamp.isNotEmpty) line(stamp, w, color: Colors.brightBlack),
      keys(['${Gl.i.lr} ${Gl.i.ud} move ${Gl.i.dot} enter open ${Gl.i.dot} s m c a g jump ${Gl.i.dot} r rescan ${Gl.i.dot} v look ${Gl.i.dot} q quit', 'enter s m c a g r v q'], w),
    ]));
  }
}
