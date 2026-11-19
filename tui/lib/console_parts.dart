// Console look, part 3: the widgets. Each is a class with its own rebuild scope; the column plan is pure.
import 'package:nocterm/nocterm.dart';
import 'console_cmd.dart';
import 'engine.dart';
import 'layout.dart';
import 'state.dart';

const _bar = Color.fromRGB(30, 34, 60), _sel = Color.fromRGB(42, 46, 72);

String padc(String s, int w, {bool right = false}) { final n = w - cells(s); return n <= 0 ? s : (right ? ' ' * n + s : s + ' ' * n); }

/// Which columns survive at a width: the id goes first, then the class word shrinks to one letter, then only the path gives way.
class ColPlan {
  ColPlan._(this.w, this.showId, this.longCls, this.idW, this.path);
  final int w, idW, path;
  final bool showId, longCls;
  static const lead = 13;

  factory ColPlan(int cols, List<Item> items) {
    final w = cols - 1, idW = items.fold<int>(2, (m, i) => cells(i.id) > m ? cells(i.id) : m).clamp(2, 12);
    if (w - lead - 7 - (idW + 1) >= 30) return ColPlan._(w, true, true, idW, w - lead - 7 - (idW + 1));
    if (w - lead - 7 >= 32) return ColPlan._(w, false, true, idW, w - lead - 7);
    return ColPlan._(w, false, false, idW, w - lead - 2);
  }

  String cls(Item i) => longCls ? (!i.supported ? 'manual' : (i.safe ? 'safe' : 'ask')) : (!i.supported ? 'M' : (i.safe ? 'S' : 'A'));
  String row(Item i, bool cur) =>
      '${cur ? Gl.i.arrow : ' '} ${!i.supported ? '   ' : (i.on ? '[x]' : '[ ]')} ${size(i.kb).padLeft(6)} ${padc(cls(i), longCls ? 6 : 1)} ${showId ? '${padc(fit(i.id, idW), idW)} ' : ''}${fitPath(i.name, path)}';
  String head(String sortKey, bool desc) {
    final m = desc ? Gl.i.down : Gl.i.up;
    String h(String n, String k, int w, {bool right = false}) => padc(sortKey == k && cells(n) + 1 <= w ? '$n$m' : n, w, right: right);
    return '      ${h('SIZE', 'size', 6, right: true)} ${h(longCls ? 'CLASS' : 'C', 'class', longCls ? 6 : 1)} ${showId ? '${padc('ID', idW)} ' : ''}${h('PATH', 'path', path)}';
  }
}

Color classColor(Item i) => !i.supported ? Colors.brightBlack : (i.safe ? Colors.green : Colors.yellow);

/// The top bar: the machine summary, fitted to the width.
class ConsoleHeader extends StatelessComponent {
  const ConsoleHeader({super.key, required this.s, required this.t});
  final AppState s;
  final Term t;

  @override
  Component build(BuildContext context) {
    final g = s.g, free = g['free_gb'] ?? '?', load = g['load'] ?? '?', n = s.items.where((i) => i.on).length;
    final tick = s.items.isEmpty ? '' : '  ticked $n (${size(s.selectedKb)})', found = s.items.isEmpty ? '' : '  found ${s.items.length} (${size(s.totalKb)})';
    final kind = s.profile?.kind ?? '';
    final txt = tier([
      ' host-hygiene console  ${kind.isEmpty ? '' : '$kind  '}free ${free}G  load $load$found$tick',
      ' hh console  free ${free}G  load $load$found$tick',
      ' hh  free ${free}G  load $load${s.items.isEmpty ? '' : '  ${s.items.length} found'}${n == 0 ? '' : '  $n ticked'}',
      ' hh  free ${free}G${n == 0 ? '' : '  $n ticked'}',
    ], t.cols);
    final c = g['status'] == 'stop' ? Colors.red : (g['status'] == 'low' ? Colors.yellow : Colors.white);
    return Text(padc(txt, t.cols), softWrap: false, style: TextStyle(color: c, backgroundColor: _bar, fontWeight: FontWeight.bold));
  }
}

/// Column titles and the visible slice of rows, padded to exactly [win] rows.
class ConsoleTable extends StatelessComponent {
  const ConsoleTable({super.key, required this.items, required this.vis, required this.plan, required this.cur, required this.top, required this.win, required this.onTap});
  final List<Item> items;
  final List<int> vis;
  final ColPlan plan;
  final int cur, top, win;
  final void Function(int) onTap;

  @override
  Component build(BuildContext context) {
    final end = (top + win).clamp(0, vis.length), w = plan.w;
    final empty = vis.isEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(' ${padc(plan.head(cm.sortKey, cm.desc), w)}', softWrap: false, style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold)),
      if (empty) Text(' ${fit('  no row matches "${cm.filter}"  (:filter alone clears it)', w)}', softWrap: false, style: TextStyle(color: Colors.brightBlack)),
      for (var p = top; p < end; p++)
        GestureDetector(
          onTap: () => onTap(vis[p]),
          child: Text(' ${padc(plan.row(items[vis[p]], vis[p] == cur), w)}', softWrap: false, style: TextStyle(color: classColor(items[vis[p]]), backgroundColor: vis[p] == cur ? _sel : null)),
        ),
      SizedBox(height: (win - (empty ? 1 : end - top)).clamp(0, 500).toDouble()),
    ]);
  }
}

/// The command line: what is being typed, else the last result, else the cost of the row under the cursor.
class ConsoleCmdLine extends StatelessComponent {
  const ConsoleCmdLine({super.key, required this.t, required this.item, required this.pos, required this.n});
  final Term t;
  final Item? item;
  final int pos, n;

  @override
  Component build(BuildContext context) {
    final w = t.cols - 1;
    if (cm.typing) return Text(fit(' :${cm.buf}${Gl.i.cursor}', w), softWrap: false, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
    if (cm.msg.isNotEmpty) return Text(fit(' ${cm.msg}', w), softWrap: false, style: TextStyle(color: cm.err ? Colors.red : Colors.cyan));
    final i = item, where = n == 0 ? '' : '${pos + 1}/$n  ';
    final tail = i == null ? '' : (i.supported ? 'cost: ${i.note}' : 'by hand: ${i.cmd}');
    return Text(fit(' $where${cm.filter.isEmpty ? '' : '[filter: ${cm.filter}]  '}$tail', w), softWrap: false, style: TextStyle(color: Colors.brightBlack));
  }
}

/// The help list drawn over the table: the whole vocabulary, one fixed set of lines.
class ConsoleHelp extends StatelessComponent {
  const ConsoleHelp({super.key, required this.t, required this.win});
  final Term t;
  final int win;

  @override
  Component build(BuildContext context) {
    const lines = [
      'COMMANDS (no shell, nothing else is accepted)',
      ':safe :ask :all :none   tick all safe / ask-first / everything / nothing',
      ':sort size|class|path   order the table (keys z c p; again reverses)',
      ':filter <text>          only rows matching text; empty text clears (key /)',
      ':look <id>              switch look live (keys: v here is text only when typing)',
      ':go  continue to confirm      :quit (or :q)  leave      :help  this list',
      'Esc closes the command line. Any key closes this help.',
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final l in lines.take(win)) Text(' ${fit(l, t.cols - 2)}', softWrap: false, style: TextStyle(color: l == lines.first ? Colors.cyan : Colors.white)),
      SizedBox(height: (win - lines.length).clamp(0, 500).toDouble()),
    ]);
  }
}
