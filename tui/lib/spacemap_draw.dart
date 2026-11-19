// Paints blocks onto a Grid, degrading with the room a block has: labels first, then sizes, then a plain fill.
import 'package:nocterm/nocterm.dart';
import 'engine.dart';
import 'layout.dart';
import 'spacemap_parts.dart';

class _Styles {
  static final _m = <String, TextStyle>{};
  static TextStyle of(Color c, {bool cur = false}) => _m.putIfAbsent('${c.hashCode}$cur', () => cur ? TextStyle(color: c, backgroundColor: hiBg, fontWeight: FontWeight.bold) : TextStyle(color: c));
}

/// Paints [b] into [g]. [cur] is the cursor item index; a block holding it gets the highlight.
void drawBlock(Grid g, Blk b, List<Item> items, int cur) {
  final u = Gl.i.utf, hit = b.idx.contains(cur), one = b.others ? null : items[b.idx.first];
  final ticked = b.idx.any((i) => items[i].on);
  final col = one == null ? Colors.white : colorOf(one), style = _Styles.of(hit ? Colors.white : col, cur: hit), dim = _Styles.of(col);
  if (b.w < 4 || b.h < 3) {
    final glyph = hit ? (u ? '█' : '@') : ticked ? (u ? '▓' : '#') : one == null ? (u ? '·' : '.') : (u ? '░' : (one.safe ? ':' : one.supported ? '%' : '.'));
    g.fill(b.x, b.y, b.w, b.h, glyph, hit ? style : dim);
    return;
  }
  const rnd = ['╭', '╮', '╰', '╯', '─', '│'], hv = ['┏', '┓', '┗', '┛', '━', '┃'], asc = ['+', '+', '+', '+', '-', '|'], tk = ['#', '#', '#', '#', '=', '#'];
  final p = u ? (ticked ? hv : rnd) : (ticked ? tk : asc), bs = hit ? style : dim, r = b.x + b.w - 1, btm = b.y + b.h - 1;
  g.fill(b.x + 1, b.y + 1, b.w - 2, b.h - 2, ' ', hit ? style : null);
  g.put(b.x, b.y, p[0], bs); g.put(r, b.y, p[1], bs); g.put(b.x, btm, p[2], bs); g.put(r, btm, p[3], bs);
  for (var x = b.x + 1; x < r; x++) { g.put(x, b.y, p[4], bs); g.put(x, btm, p[4], bs); }
  for (var y = b.y + 1; y < btm; y++) { g.put(b.x, y, p[5], bs); g.put(r, y, p[5], bs); }
  final iw = b.w - 2, ih = b.h - 2, kb = b.idx.fold<int>(0, (s, i) => s + items[i].kb), sz = size(kb);
  final name = one == null ? '+${b.idx.length} others' : one.name, tag = one == null ? '' : clsOf(one);
  final tx = b.x + 1;
  String? l0, l1;
  if (ih >= 2) {
    if (one == null && iw < 10 && iw >= 3) l0 = '+${b.idx.length}';
    else if (iw >= 6) l0 = (ticked && iw >= 8 ? '${Gl.i.check} ' : '') + fitPath(name, iw - (ticked && iw >= 8 ? 2 : 0));
    if (cells(sz) <= iw) l1 = iw >= cells(sz) + 1 + tag.length && tag.isNotEmpty ? '$sz $tag' : sz;
  } else {
    if (iw >= cells(sz) + 5) l0 = '${fitPath(name, iw - cells(sz) - 1)} $sz';
    else if (cells(sz) <= iw) l0 = sz;
  }
  if (l0 != null) g.put(tx, b.y + 1, l0, style, to: r);
  if (l1 != null) g.put(tx, b.y + 2, l1, hit ? style : dim, to: r);
}
