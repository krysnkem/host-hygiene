// Cockpit look: layout geometry, a bordered pane drawn from plain text rows, and small text helpers.
import 'package:nocterm/nocterm.dart';
import 'layout.dart';

/// A styled run of text; [bg] falls back to the row's background.
class Seg {
  const Seg(this.t, {this.fg, this.bg, this.bold = false});
  final String t;
  final Color? fg, bg;
  final bool bold;
}

/// One pane row. [tap] makes the whole row clickable.
class Ln {
  const Ln(this.segs, {this.bg, this.tap});
  final List<Seg> segs;
  final Color? bg;
  final void Function()? tap;
}

/// Where every region goes, from the terminal size alone. Side by side from 100 columns, stacked below.
class Geo {
  Geo(Term t)
      : cols = t.cols,
        w = t.cols - 2,
        hy = t.rows >= 24 ? 2 : 1,
        totals = t.rows >= 20,
        stacked = t.cols < 100 {
    body = t.rows - 1 - (hy + 1 + (totals ? 1 : 0));
    if (stacked) {
      wA = wB = w;
      hB = body >= 14 ? 7 : (body >= 11 ? 6 : 5);
      hA = body - hB;
    } else {
      wA = w * 3 ~/ 5; wB = w - wA - 1; hA = hB = body;
    }
  }
  final int cols, w, hy;
  final bool totals, stacked;
  late final int body, wA, wB, hA, hB;
}

/// Text cut or padded to exactly [w] cells, as a Row of Texts (borders excluded).
List<Component> segTexts(List<Seg> segs, int w, Color? bg) {
  final out = <Component>[];
  var left = w;
  void add(String t, Seg s) => out.add(Text(t, softWrap: false, style: TextStyle(color: s.fg, backgroundColor: s.bg ?? bg, fontWeight: s.bold ? FontWeight.bold : null)));
  for (final s in segs) {
    if (left <= 0) break;
    if (s.t.isEmpty) continue;
    final f = cells(s.t) <= left ? s.t : fit(s.t, left);
    add(f, s); left -= cells(f);
  }
  if (left > 0) add(' ' * left, const Seg(''));
  return out;
}

/// A borderless row of [w] cells (header, footer).
Component rowOf(List<Seg> segs, int w, {Color? bg}) => Row(children: segTexts(segs, w, bg));

/// A titled box of [w] x [h]; [rows] fill the h-2 inner rows. Same shape in ASCII.
class Pane extends StatelessComponent {
  const Pane({super.key, required this.title, required this.w, required this.h, required this.hot, required this.rows});
  final String title;
  final int w, h;
  final bool hot;
  final List<Ln> rows;

  @override
  Component build(BuildContext context) {
    final g = Gl.i, u = g.utf, st = TextStyle(color: hot ? Colors.cyan : Colors.brightBlack, fontWeight: hot ? FontWeight.bold : null);
    final hz = u ? '─' : '-', v = u ? '│' : '|', t = fit(title, w - 5);
    final top = '${u ? '╭' : '+'}$hz $t ${hz * (w - 5 - cells(t))}${u ? '╮' : '+'}';
    final bottom = '${u ? '╰' : '+'}${hz * (w - 2)}${u ? '╯' : '+'}';
    return SizedBox(width: w.toDouble(), height: h.toDouble(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(top, softWrap: false, style: st),
      for (var r = 0; r < h - 2; r++) _row(r < rows.length ? rows[r] : const Ln([]), v, st),
      Text(bottom, softWrap: false, style: st),
    ]));
  }

  Component _row(Ln l, String v, TextStyle st) {
    final row = Row(children: [Text('$v ', style: st), ...segTexts(l.segs, w - 4, l.bg), Text(' $v', style: st)]);
    return l.tap == null ? row : GestureDetector(onTap: l.tap!, child: row);
  }
}

/// [s] wrapped to [w] cells, at most [max] rows (the last one cut with an ellipsis when text remains).
List<String> wrapTo(String s, int w, int max) {
  final sp = wrapSpans(s, w.clamp(4, 400)), out = <String>[];
  for (var i = 0; i < sp.length && i < max; i++) { out.add(s.substring(sp[i][0], sp[i][1])); }
  if (sp.length > max) out[max - 1] = fit(s.substring(sp[max - 1][0]), w);
  return out;
}

/// "safe  " / "ask   " / "manual": the class tag, the same words and colours as the guided look.
String tagOf(bool safe, bool supported) => safe ? 'safe  ' : (supported ? 'ask   ' : 'manual');
Color colorOf(bool safe, bool supported) => !supported ? Colors.brightBlack : (safe ? Colors.green : Colors.yellow);

/// A "[ ] label" choice row in the same style as the other looks' buttons.
List<Seg> choiceSegs(List<String> opts, int sel) => [
      for (var i = 0; i < opts.length; i++) ...[
        Seg(i == sel ? ' ${Gl.i.arrow} ${opts[i]} ' : '   ${opts[i]} ', fg: i == sel ? Colors.black : Colors.white, bg: i == sel ? Colors.magenta : null, bold: i == sel),
        const Seg('  '),
      ]
    ];
