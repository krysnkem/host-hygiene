// Cockpit look: what the two panes hold at each stage.
import 'package:nocterm/nocterm.dart';
import 'cockpit_parts.dart';
import 'engine.dart';
import 'layout.dart';
import 'limits_text.dart';
import 'look.dart';
import 'state.dart';

class PaneSet {
  PaneSet(this.ta, this.a, this.tb, this.b, {this.hotB = false});
  final String ta, tb;
  final List<Ln> a, b;
  final bool hotB;
}

String _clean(String r) => r.split('(').first.replaceFirst(RegExp(r'^done\s+'), '').trim();
const _hl = Color.fromRGB(42, 46, 72);
const _stays = {'safe': 'your source and settings; it rebuilds on its own', 'ask': 'other projects keep working; shared files re-download', 'hand': 'this tool removes nothing here; run the command yourself'};

/// [body] rows trimmed to leave room for the [tail] rows, which always show.
List<Ln> _fill(List<Ln> body, List<Ln> tail, int cap) => [...body.take((cap - tail.length).clamp(0, 99)), ...tail];

PaneSet panesFor(AppState s, Term t, Geo g, Actions act) {
  final st = s.stage, capA = g.hA - 2, capB = g.hB - 2, iA = g.wA - 4, iB = g.wB - 4, spin = Gl.i.spin[s.tick % 10];
  const dim = Colors.brightBlack;
  Ln text(String x, {Color? c}) => Ln([Seg(x, fg: c ?? Colors.white)]);
  switch (st) {
    case Stage.look:
      return PaneSet('Status', [Ln([Seg('$spin Looking around your machine', fg: Colors.cyan)])], 'Hy', [text('Checking disk, tools and projects.', c: dim)]);
    case Stage.limits:
      final q = [for (final r in wrapTo(tier(['Set the limits I should watch? They keep a build from starting on a machine that is too full or too busy.', 'Set the limits I should watch?', 'Set the limits?'], 400), iA, 3)) text(r)];
      return PaneSet('Limits', _fill(q, [Ln(choiceSegs(iA < 40 ? ['Use suggestions', 'Later'] : ['Use my suggestions', "I'll set them later"], s.sel))], capA), 'What they mean',
          [for (final l in limitsLines(s.g, iB)) text(l, c: dim)]);
    case Stage.pick:
      return _pick(s, g, act, capA, iA, capB, iB);
    case Stage.confirm:
      final more = s.chosen.length - capA, shown = more > 0 ? capA - 1 : s.chosen.length;
      final a = [for (final i in s.chosen.take(shown)) Ln([Seg('${size(i.kb).padLeft(6)}  ${fitPath(i.name, iA - 8)}', fg: colorOf(i.safe, true))]), if (more > 0) text('...and ${more + 1} more', c: dim)];
      final kb = s.chosen.fold(0, (n, i) => n + i.kb), warn = s.chosen.any((i) => !i.safe);
      final b = [
        for (final r in wrapTo(tier(['Remove ${s.chosen.length} item(s), about ${size(kb)}? A log is written. No undo.', 'Remove ${s.chosen.length} (${size(kb)})? No undo.'], 400), iB, 2)) text(r),
        if (warn) Ln([Seg(fit('Yellow items cost more to rebuild.', iB), fg: Colors.yellow)]),
      ];
      return PaneSet('You chose', a, 'Remove?', _fill(b, [Ln(choiceSegs(iB < 40 ? ['No, back', 'Yes, remove'] : ['No, go back', 'Yes, remove them'], s.sel))], capB), hotB: true);
    case Stage.work:
      final n = s.total == 0 ? 0.0 : s.finished / s.total, bw = (iB - 16).clamp(4, 40), fill = (bw * n).round(), u = Gl.i.utf;
      final bar = '${(u ? '█' : '#') * fill}${(u ? '░' : '.') * (bw - fill)} ${s.finished}/${s.total} ${(n * 100).round()}%';
      final a = [for (final r in s.results.reversed.take(capA)) Ln([Seg(fit('${r.startsWith('done') ? Gl.i.check : '!'} ${r.startsWith('done') ? _clean(r) : readable(r)}', iA), fg: r.startsWith('done') ? Colors.green : Colors.yellow)])];
      return PaneSet('Removed', a, 'Working', [Ln([Seg(bar, fg: Colors.green)]), Ln([Seg('$spin ${s.current.isEmpty ? 'starting' : 'removing ${fitPath(s.current, iB - 12)}'}', fg: Colors.cyan)])]);
    case Stage.done:
      final a = [
        for (final p in s.problems.take(3)) ...[for (final (i, r) in wrapTo(p, iA - 2, 2).indexed) Ln([Seg('${i == 0 ? '! ' : '  '}$r', fg: Colors.yellow)])],
        for (final r in s.results.where((r) => r.startsWith('done')).map((r) => _clean(r))) Ln([Seg(fit('${Gl.i.check} $r', iA), fg: Colors.green)]),
      ];
      final manual = s.items.where((i) => !i.supported).length;
      final b = [
        if (s.ran > 0) text('Freed ${s.freed} in ${s.ran} item${s.ran == 1 ? '' : 's'}', c: Colors.green),
        if (s.ran > 0) Ln([Seg(fit('Free space: ${s.freeBefore} ${Gl.i.to} ${s.freeAfter} GiB', iB), fg: dim)]),
        if (manual > 0) Ln([Seg(fit('$manual left by hand: host-hygiene.sh plan', iB), fg: dim)]),
      ];
      return PaneSet(s.problems.isEmpty ? 'Result' : 'Result (some left alone)', a, 'Summary', _fill(b.isEmpty ? [text('Nothing to clear.', c: dim)] : b, [Ln(choiceSegs(['Quit'], 0))], capB), hotB: true);
  }
}

PaneSet _pick(AppState s, Geo g, Actions act, int capA, int iA, int capB, int iB) {
  final it = s.items, end = (s.top + capA).clamp(0, it.length), n = it.where((i) => i.on).length, kb = s.selectedKb, nameW = (iA - 21).clamp(6, 300);
  final rng = it.length > capA ? '  (${s.top + 1}-$end/${it.length})' : '';
  final title = tier(['Pick what to clear  $n ticked, ${size(kb)}$rng', 'Pick  $n ticked, ${size(kb)}$rng', 'Pick $n/${size(kb)}'], g.wA - 6);
  final a = it.isEmpty ? [const Ln([Seg('Nothing to clear.')])] : [
    for (var i = s.top; i < end; i++)
      Ln([Seg('${i == s.cur ? Gl.i.arrow : ' '} ${it[i].supported ? (it[i].on ? '[x]' : '[ ]') : '   '} ${size(it[i].kb).padLeft(6)}  ${tagOf(it[i].safe, it[i].supported)} ${fitPath(it[i].name, nameW)}', fg: colorOf(it[i].safe, it[i].supported))], bg: i == s.cur ? _hl : null, tap: () => act.tap(i)),
  ];
  return PaneSet(title, a, 'About this item', it.isEmpty ? const [] : _detail(it[s.cur.clamp(0, it.length - 1)], capB, iB));
}

List<Ln> _detail(Item c, int cap, int w) {
  const dim = Colors.brightBlack;
  final per = cap >= 7 ? 2 : 1;
  List<Ln> para(String label, String body, Color col) => [for (final (i, r) in wrapTo(body, w - 6, per).indexed) Ln([Seg(i == 0 ? label.padRight(6) : '      ', fg: dim), Seg(r, fg: col)])];
  final col = colorOf(c.safe, c.supported);
  return [
    Ln([Seg('${tagOf(c.safe, c.supported).trim()}  ${size(c.kb)}', fg: col, bold: true), Seg('  ${fitPath(c.name, w - 14)}', fg: Colors.white)]),
    ...para('Cost', c.note.isEmpty ? 'none noted' : c.note, Colors.white),
    ...para(c.supported ? 'Runs' : 'Hand', c.cmd, Colors.white),
    ...para('Stays', _stays[c.safe ? 'safe' : (c.supported ? 'ask' : 'hand')]!, Colors.green),
  ].take(cap).toList();
}
