// Dashboard tiles: geometry, the disk bar, the load graph, the process lists. Widget classes only; no _buildX methods.
import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'dashboard_data.dart';
import 'layout.dart';
import 'ui.dart';

/// Where everything goes for a terminal size. 3 columns from 100 cols, 2 from 70, else 1.
class DashGeo {
  DashGeo(Term t)
      : cols = t.cols,
        rows = t.rows {
    mode = cols >= 100 ? 3 : (cols >= 70 ? 2 : 1);
    avail = rows - 4; // title row and the three footer rows
    lines = mode == 1 || (mode == 2 && avail < 17);
    c = mode == 3 ? (avail - 9).clamp(1, 5) : (mode == 2 && !lines ? 3 : 0);
    gh = lines ? 2 + (avail - 9).clamp(1, 6) : (mode == 3 ? c + 2 : 10);
  }
  final int cols, rows;
  late final int mode, avail, c, gh;
  late final bool lines;
  int get list => (avail - gh - 2).clamp(1, 60);
  /// Room for the confirm / work / done content (no footer rows there).
  int get slot => (rows - 1 - gh - 2).clamp(1, 60);
  int get tileW => mode == 3 ? (cols - 4) ~/ 3 : (cols - 3) ~/ 2;
}

Color _lvl(double v, double warn, double bad) => v >= bad ? Colors.red : (v >= warn ? Colors.yellow : Colors.green);

String spark(List<double> h, int w, double top) {
  final g = Gl.i.utf ? '▁▂▃▄▅▆▇█' : '._-=+*#%', v = h.length > w ? h.sublist(h.length - w) : h;
  return v.map((x) => g[((x / top).clamp(0.0, 1.0) * 7).round()]).join();
}

/// Free space against the soft floor (yellow mark) and hard stop (red mark). The bar spans 0 to three soft floors.
class DiskBar extends StatelessComponent {
  const DiskBar({super.key, required this.free, required this.lim, required this.w});
  final double free;
  final Lim lim;
  final int w;
  @override
  Component build(BuildContext context) {
    final scale = (lim.soft * 3).clamp(1.0, 1e9), n = w.clamp(4, 80), fill = (free / scale * n).clamp(0, n).round();
    final mf = (lim.soft / scale * n).round().clamp(0, n - 1), mh = (lim.hard / scale * n).round().clamp(0, n - 1);
    final col = free < lim.hard ? Colors.red : (free < lim.soft ? Colors.yellow : Colors.green), mark = Gl.i.utf ? '┃' : '|';
    final cs = <(String, Color)>[for (var i = 0; i < n; i++) i == mh ? (mark, Colors.red) : (i == mf ? (mark, Colors.yellow) : (i < fill ? (Gl.i.utf ? '█' : '#', col) : (Gl.i.utf ? '░' : '.', Colors.brightBlack)))];
    final runs = <Component>[];
    for (var i = 0; i < n;) {
      var j = i;
      while (j < n && cs[j] == cs[i]) { j++; }
      runs.add(Text(cs[i].$1 * (j - i), style: TextStyle(color: cs[i].$2)));
      i = j;
    }
    return Row(children: runs);
  }
}

Component _t(String s, int w, {Color? color, bool bold = false}) => line(s, w, color: color, bold: bold);

/// Disk tile lines for [c] content rows ([c] 1 and 2 are the squeezed forms). [pre] labels the one-line form.
List<Component> diskLines(DashData d, Lim lim, int w, int c, {String pre = ''}) {
  final f = d.freeGb, col = _lvl(-f, -lim.soft, -lim.hard), free = '${f.toStringAsFixed(1)} GiB free', of = d.totalKb > 0 ? ' of ${d.totalGb.round()} GiB' : '';
  final st = f < lim.hard ? 'below the hard stop: no builds' : (f < lim.soft ? 'below the soft floor' : 'above the soft floor');
  final lm = tier(['floor ${lim.soft.round()} ${Gl.i.dot} stop ${lim.hard.round()} GiB', 'floor ${lim.soft.round()} stop ${lim.hard.round()}'], w);
  if (c == 1) return [Row(children: [Text('$pre${f.toStringAsFixed(1)}G free ', style: TextStyle(color: col)), DiskBar(free: f, lim: lim, w: w - cells('$pre${f.toStringAsFixed(1)}G free '))])];
  if (c == 2) return [_t('$free $lm', w, color: col), DiskBar(free: f, lim: lim, w: w)];
  return [_t('$free$of', w, color: col, bold: true), DiskBar(free: f, lim: lim, w: w), _t(lm, w), if (c > 3) _t(st, w, color: col), if (c > 4) _t(d.totalKb > 0 ? 'used ${(100 - 100 * d.freeGb / d.totalGb).round()}%' : '', w, color: Colors.brightBlack)];
}

List<Component> loadLines(DashData d, Lim lim, int w, int c, {String pre = ''}) {
  final col = _lvl(d.l1, lim.load * 0.75, lim.load), top = [lim.load, ...d.hist].reduce((a, b) => a > b ? a : b);
  final now = 'now ${d.l1.toStringAsFixed(2)} ${Gl.i.dot} limit ${lim.load.toStringAsFixed(lim.load % 1 == 0 ? 0 : 1)}';
  if (c == 1) return [Row(children: [Text('$pre$now ', style: TextStyle(color: col)), Text(spark(d.hist, w - cells('$pre$now '), top), style: TextStyle(color: Colors.cyan))])];
  final sp = Text(spark(d.hist, w, top), style: TextStyle(color: Colors.cyan));
  return [_t(now, w, color: col, bold: true), sp, if (c > 2) _t(tier(['1m ${d.l1.toStringAsFixed(2)} ${Gl.i.dot} 5m ${d.l5.toStringAsFixed(2)} ${Gl.i.dot} 15m ${d.l15.toStringAsFixed(2)}', '${d.l1.toStringAsFixed(1)} ${d.l5.toStringAsFixed(1)} ${d.l15.toStringAsFixed(1)}'], w), w), if (c > 3) _t('${(100 * d.l1 / Platform.numberOfProcessors).round()}% of ${Platform.numberOfProcessors} cores', w, color: Colors.brightBlack)];
}

/// Top consumers: cpu rows first, then memory rows. One row gets both leaders.
List<Component> procLines(DashData d, int w, int n) {
  if (!d.procsLoaded) return [_t('reading processes...', w, color: Colors.brightBlack)];
  Component row(String tag, Proc p, bool byCpu) {
    final a = byCpu ? '${p.cpu.round()}%'.padLeft(4) : '${p.mb}M'.padLeft(5), b = byCpu ? '${p.mb}M'.padLeft(5) : '${p.cpu.round()}%'.padLeft(4);
    return _t('$tag $a $b ${p.name}', w, color: p.cpu >= 50 ? Colors.yellow : null, bold: p.cpu >= 50);
  }
  if (n == 1) {
    final c = d.byCpu.isEmpty ? null : d.byCpu.first, m = d.byMem.isEmpty ? null : d.byMem.first;
    return [_t('${c == null ? '' : 'cpu ${fit(c.name, 16)} ${c.cpu.round()}%'}${m == null ? '' : '  mem ${fit(m.name, 16)} ${m.mb}M'}', w, color: (c?.cpu ?? 0) >= 50 ? Colors.yellow : null)];
  }
  final nc = (n + 1) ~/ 2;
  return [for (final p in d.byCpu.take(nc)) row('cpu', p, true), for (final p in d.byMem.take(n - nc)) row('mem', p, false)];
}

/// A titled box of exactly [c] content rows, so neighbours always match in height.
class DashTile extends StatelessComponent {
  const DashTile({super.key, required this.title, required this.rows, required this.c});
  final String title;
  final List<Component> rows;
  final int c;
  @override
  Component build(BuildContext context) => box(title, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [...rows.take(c), for (var i = rows.length; i < c; i++) SizedBox(height: 1)]));
}

/// Disk, Load and Processes, flowed for the size. Compact sizes drop the borders and use one row per gauge.
class DashGauges extends StatelessComponent {
  const DashGauges({super.key, required this.g, required this.d, required this.lim});
  final DashGeo g;
  final DashData d;
  final Lim lim;
  @override
  Component build(BuildContext context) {
    final w = g.tileW - 4, cores = Platform.numberOfProcessors;
    if (g.lines) {
      final lw = g.cols - 3, p = g.gh - 2;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [...diskLines(d, lim, lw, 1, pre: 'Disk  '), ...loadLines(d, lim, lw, 1, pre: 'Load  '), ...procLines(d, lw, p)]);
    }
    final disk = DashTile(title: 'Disk', rows: diskLines(d, lim, w, g.mode == 3 ? g.c : 3), c: g.mode == 3 ? g.c : 3);
    final load = DashTile(title: 'Load ($cores cores)', rows: loadLines(d, lim, w, g.mode == 3 ? g.c : 3), c: g.mode == 3 ? g.c : 3);
    final pc = g.mode == 3 ? g.c : 8, procs = DashTile(title: 'Heaviest processes', rows: procLines(d, w, pc), c: pc);
    if (g.mode == 3) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: disk), SizedBox(width: 1), Expanded(child: load), SizedBox(width: 1), Expanded(child: procs)]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [disk, load])), SizedBox(width: 1), Expanded(child: procs)]);
  }
}
