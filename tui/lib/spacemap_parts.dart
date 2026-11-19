// Space map pieces: the treemap layout (pure, cached by the caller) and the cell grid it is painted on.
import 'package:nocterm/nocterm.dart';
import 'engine.dart';
import 'layout.dart';

/// One rectangle of the map. [idx] holds item indexes: one item, or several folded into an "others" block.
class Blk {
  const Blk(this.x, this.y, this.w, this.h, this.idx);
  final int x, y, w, h;
  final List<int> idx;
  bool get others => idx.length > 1;
}

String clsOf(Item i) => !i.supported ? 'manual' : (i.safe ? 'safe' : 'ask');
Color colorOf(Item i) => !i.supported ? Colors.brightBlack : (i.safe ? Colors.green : Colors.yellow);
const hiBg = Color.fromRGB(42, 46, 72);

/// Slice-and-dice by weight: sort by size, keep what earns at least [minArea] cells, fold the rest into one others block, then bisect the rectangle along its longer side (a cell is about twice as tall as wide). Deterministic, O(n log n).
List<Blk> layoutMap(List<Item> items, int w, int h, {int minArea = 6}) {
  if (items.isEmpty || w < 1 || h < 1) return const [];
  final order = [for (var i = 0; i < items.length; i++) i]..sort((a, b) { final c = items[b].kb.compareTo(items[a].kb); return c != 0 ? c : a.compareTo(b); });
  int wt(int i) => items[i].kb < 1 ? 1 : items[i].kb;
  final tot = order.fold<int>(0, (s, i) => s + wt(i)), cap = (w * h ~/ minArea).clamp(1, 400);
  var keep = 0;
  while (keep < order.length && keep < cap - 1 && w * h * wt(order[keep]) / tot >= minArea) { keep++; }
  if (keep == 0) keep = 1;
  if (order.length - keep == 1) keep++;
  final groups = <List<int>>[for (var i = 0; i < keep; i++) [order[i]], if (keep < order.length) order.sublist(keep)];
  final weights = [for (final g in groups) g.fold<int>(0, (s, i) => s + wt(i))];
  final out = <Blk>[];
  void split(int a, int b, int x, int y, int rw, int rh) {
    if (b - a == 1) { out.add(Blk(x, y, rw, rh, groups[a])); return; }
    var all = 0;
    for (var i = a; i < b; i++) { all += weights[i]; }
    var acc = 0, k = a + 1, best = all;
    for (var i = a; i < b - 1; i++) { acc += weights[i]; final d = (2 * acc - all).abs(); if (d < best) { best = d; k = i + 1; } }
    var left = 0;
    for (var i = a; i < k; i++) { left += weights[i]; }
    var cutW = rw >= 2 * rh;
    if (cutW && rw < 2) cutW = false;
    if (!cutW && rh < 2) cutW = rw >= 2;
    if (cutW ? rw < 2 : rh < 2) { out.add(Blk(x, y, rw, rh, [for (var i = a; i < b; i++) ...groups[i]])); return; }
    if (cutW) { final c = (rw * left / all).round().clamp(1, rw - 1); split(a, k, x, y, c, rh); split(k, b, x + c, y, rw - c, rh); }
    else { final c = (rh * left / all).round().clamp(1, rh - 1); split(a, k, x, y, rw, c); split(k, b, x, y + c, rw, rh - c); }
  }
  split(0, groups.length, 0, 0, w, h);
  return out;
}

/// A [w] x [h] canvas of cells. A cell holds one glyph (or '' behind a double-width one) and a style.
class Grid {
  Grid(this.w, this.h) : ch = [for (var i = 0; i < h; i++) List.filled(w, ' ')], st = [for (var i = 0; i < h; i++) List<TextStyle?>.filled(w, null)];
  final int w, h;
  final List<List<String>> ch;
  final List<List<TextStyle?>> st;

  void put(int x, int y, String s, TextStyle? style, {int? to}) {
    final end = to ?? w;
    for (final r in s.runes) {
      final c = runeCells(r);
      if (c == 0 || x + c > end || x < 0 || y < 0 || y >= h) { if (c != 0) { return; } continue; }
      ch[y][x] = String.fromCharCode(r); st[y][x] = style;
      if (c == 2) { ch[y][x + 1] = ''; st[y][x + 1] = style; }
      x += c;
    }
  }

  void fill(int x, int y, int rw, int rh, String g, TextStyle? style) {
    for (var j = y; j < y + rh; j++) { for (var i = x; i < x + rw; i++) { put(i, j, g, style); } }
  }

  /// One row as runs of equal style, so the terminal gets few Text widgets.
  Component row(int y) {
    final kids = <Component>[];
    final b = StringBuffer();
    TextStyle? cur = st[y][0];
    for (var x = 0; x < w; x++) {
      if (!identical(st[y][x], cur)) { kids.add(Text(b.toString(), softWrap: false, style: cur)); b.clear(); cur = st[y][x]; }
      b.write(ch[y][x]);
    }
    kids.add(Text(b.toString(), softWrap: false, style: cur));
    return Row(children: kids);
  }
}
