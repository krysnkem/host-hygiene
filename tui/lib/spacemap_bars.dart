// The collapsed body and the three bottom lines (detail / status / keys) that every stage of the space map shares.
import 'package:nocterm/nocterm.dart';
import 'engine.dart';
import 'layout.dart';
import 'look.dart';
import 'spacemap_parts.dart';
import 'state.dart';
import 'ui.dart';

const _classes = ['safe', 'ask', 'manual'];
Color _col(String c) => c == 'safe' ? Colors.green : (c == 'ask' ? Colors.yellow : Colors.brightBlack);

/// Rows of the bar block for [h] body rows: three bars, one stacked bar, or none.
int barRows(int h) => h >= 6 ? 3 : (h >= 4 ? 1 : 0);
/// List rows under the bars: the same figure the controller uses for paging.
int collapsedList(int h) => (h - barRows(h)).clamp(1, 60);

class CollapsedView extends StatelessComponent {
  const CollapsedView({super.key, required this.items, required this.w, required this.h, required this.cur, required this.top});
  final List<Item> items;
  final int w, h, cur, top;

  @override
  Component build(BuildContext context) {
    final g = Gl.i, tot = {for (final c in _classes) c: 0}, cnt = {for (final c in _classes) c: 0};
    for (final i in items) { tot[clsOf(i)] = tot[clsOf(i)]! + i.kb; cnt[clsOf(i)] = cnt[clsOf(i)]! + 1; }
    final all = tot.values.fold<int>(0, (a, b) => a + b), nb = barRows(h), win = collapsedList(h), end = (top + win).clamp(0, items.length);
    final fill = g.utf ? '█' : '#', rest = g.utf ? '░' : '.';
    final out = <Component>[];
    if (nb == 3) {
      final bw = (w - 7 - 7 - 9).clamp(0, 400);
      for (final c in _classes) {
        final n = all == 0 ? 0 : (bw * tot[c]! / all).round().clamp(tot[c]! > 0 && bw > 0 ? 1 : 0, bw);
        out.add(Row(children: [
          Text('${c.padRight(6)} ${size(tot[c]!).padLeft(6)} ', softWrap: false, style: TextStyle(color: _col(c), fontWeight: FontWeight.bold)),
          if (bw > 0) Text(fill * n, softWrap: false, style: TextStyle(color: _col(c))),
          if (bw > 0) Text(rest * (bw - n), softWrap: false, style: TextStyle(color: Colors.brightBlack)),
          if (w >= 30) Text(' ${cnt[c]}x', softWrap: false, style: TextStyle(color: Colors.brightBlack)),
        ]));
      }
    } else if (nb == 1) {
      final kids = <Component>[];
      var used = 0;
      for (final c in _classes) {
        final n = c == 'manual' ? w - used : (all == 0 ? 0 : (w * tot[c]! / all).round().clamp(0, w - used));
        used += n;
        kids.add(Text(fill * n, softWrap: false, style: TextStyle(color: _col(c))));
      }
      out.add(Row(children: kids));
    }
    final nameW = (w - 22).clamp(4, 300);
    for (var i = top; i < end; i++) {
      final it = items[i], hit = i == cur;
      out.add(Text(fit('${hit ? g.arrow : ' '} ${it.supported ? (it.on ? '[x]' : '[ ]') : '   '} ${size(it.kb).padLeft(6)} ${clsOf(it).padRight(6)} ${fitPath(it.name, nameW)}', w), softWrap: false, style: TextStyle(color: colorOf(it), backgroundColor: hit ? hiBg : null)));
    }
    while (out.length < h) { out.add(SizedBox(height: 1)); }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: out.take(h).toList());
  }
}

/// The three bottom lines for the current stage.
List<Component> bottom(AppState s, int w, bool open, bool auto) {
  final g = Gl.i, tg = auto ? '' : (open ? ' ${g.dot} tab collapse' : ' ${g.dot} tab expand');
  final c = s.items.isEmpty ? null : s.items[s.cur.clamp(0, s.items.length - 1)];
  final n = s.items.where((i) => i.on).length, tick = size(s.selectedKb);
  switch (s.stage) {
    case Stage.look:
      return [line('  ${g.spin[s.tick % 10]} Looking around your machine', w, color: Colors.cyan), SizedBox(height: 1), SizedBox(height: 1)];
    case Stage.limits:
      return [line('  Set limits? Disk: warn <${s.g['min_free_gb'] ?? '15'}, stop <${s.g['hard_gb'] ?? '5'} GiB free. CPU load max ${s.g['max_load'] ?? '8'}. Memory: no limit.', w), choices(['Use my suggestions', "I'll set them later"], s.sel), keys(['${g.lr} move ${g.dot} enter choose'], w)];
    case Stage.confirm:
      return [
        Text(tier(['  Remove these ${s.chosen.length} item(s), ${size(s.chosen.fold(0, (a, i) => a + i.kb))}? A log is written. No undo.', '  Remove ${s.chosen.length} item(s)? No undo.', '  Remove ${s.chosen.length}? No undo.'], w), softWrap: false, style: TextStyle(color: s.chosen.any((i) => !i.safe) ? Colors.yellow : Colors.white)),
        choices(['No, go back', 'Yes, remove them'], s.sel),
        keys(['${g.lr} move ${g.dot} enter choose ${g.dot} esc back ${g.dot} q quit', '${g.lr} ${g.dot} enter ${g.dot} esc ${g.dot} q', '${g.lr} enter esc q'], w),
      ];
    case Stage.work:
      final bw = (w - 20).clamp(6, 40);
      return [
        Row(children: [Text('  ${g.spin[s.tick % 10]} ', style: TextStyle(color: Colors.cyan)), SizedBox(width: bw.toDouble(), child: ProgressBar(value: s.total == 0 ? 0 : s.finished / s.total, valueColor: Colors.green, showPercentage: true, fillCharacter: g.utf ? '█' : '#', emptyCharacter: g.utf ? '░' : '.')), Text(' ${s.finished}/${s.total}')]),
        line('  ${s.current.isEmpty ? 'starting' : 'removing ${fitPath(s.current, w - 14)}'}', w, color: Colors.cyan),
        line(s.results.isEmpty ? '' : '  ${g.check} ${s.results.last.split('(').first.trim()}', w, color: Colors.green),
      ];
    case Stage.done:
      final manual = s.items.where((i) => !i.supported).length;
      return [
        line(s.ran > 0 ? '  Done. Cleared ${s.freed} across ${s.ran} item${s.ran == 1 ? '' : 's'}.  Free: ${s.freeBefore} ${g.to} ${s.freeAfter} GiB' : '  Nothing was removed.', w, color: Colors.green),
        line(s.problems.isNotEmpty ? '  ! ${s.problems.first}' : (manual > 0 ? '  $manual more left to remove by hand: host-hygiene.sh plan' : ''), w, color: s.problems.isNotEmpty ? Colors.yellow : Colors.brightBlack),
        keys(doneKeys(), w),
      ];
    case Stage.pick:
      return [
        line(c == null ? '' : '  ${size(c.kb)} ${clsOf(c)}  ${c.supported ? 'Cost: ${c.note}' : 'By hand: ${c.cmd}'}', w, color: Colors.brightBlack),
        Text(tier(['  Selected: $n item(s), about $tick', '  $n selected, $tick', '  $n sel $tick'], w), softWrap: false, style: TextStyle(color: Colors.magenta, fontWeight: FontWeight.bold)),
        keys(['${g.ud} move ${g.dot} space tick ${g.dot} s safe ${g.dot} f ask ${g.dot} a all ${g.dot} n none ${g.dot} enter go$tg ${g.dot} q quit', '${g.ud} ${g.dot} space ${g.dot} s f a n ${g.dot} enter${auto ? '' : ' ${g.dot} tab'} ${g.dot} q', '${g.ud} space s f a n enter q'], w, tag: lookKey(s)),
      ];
  }
}
