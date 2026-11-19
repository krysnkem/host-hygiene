// The four body views under the mascot. Each is a widget class so it has its own rebuild scope.
import 'package:nocterm/nocterm.dart';
import 'engine.dart';
import 'layout.dart';
import 'limits_text.dart';
import 'ui.dart';

class PickView extends StatelessComponent {
  const PickView({super.key, required this.t, required this.items, required this.cur, required this.top, required this.win, required this.onTap, this.tag = ''});
  final Term t;
  final List<Item> items;
  final int cur, top, win;
  /// The look-switch hint (see lookKey); empty for the plain look.
  final String tag;
  final void Function(int) onTap;

  @override
  Component build(BuildContext context) {
    final g = Gl.i, end = (top + win).clamp(0, items.length);
    final tot = items.where((i) => i.on).fold<int>(0, (s, i) => s + i.kb);
    final n = items.where((i) => i.on).length;
    final nameW = (t.cols - 8 - 21).clamp(6, 300);
    final more = '${top > 0 ? '${g.up} more above ' : ''}${end < items.length ? '${g.down} more below' : ''}';
    final title = items.length > win
        ? tier(['Pick what to clear  (${top + 1}-$end of ${items.length})', 'Pick (${top + 1}-$end of ${items.length})', '${top + 1}-$end/${items.length}'], t.cols - 14)
        : 'Pick what to clear';
    final c = items.isEmpty ? null : items[cur];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      box(title, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = top; i < end; i++)
          GestureDetector(
            onTap: () => onTap(i),
            child: Text('${i == cur ? g.arrow : ' '} ${items[i].supported ? (items[i].on ? '[x]' : '[ ]') : '   '} ${size(items[i].kb).padLeft(6)}  ${items[i].safe ? 'safe  ' : (items[i].supported ? 'ask   ' : 'manual')} ${fitPath(items[i].name, nameW)}',
                softWrap: false,
                style: TextStyle(color: !items[i].supported ? Colors.brightBlack : (items[i].safe ? Colors.green : Colors.yellow), backgroundColor: i == cur ? Color.fromRGB(42, 46, 72) : null)),
          ),
      ])),
      if (c != null) line('  ${c.supported ? 'Cost: ${c.note}' : 'By hand: ${c.cmd}'}', t.inner, color: Colors.brightBlack),
      Text(tier(['  Selected: $n item(s), about ${size(tot)}${more.isEmpty ? '' : '   $more'}', '  $n selected, ${size(tot)}${more.isEmpty ? '' : '  $more'}', '  $n sel ${size(tot)} ${more.replaceAll(' more', '').replaceAll(' ', '')}'], t.inner), softWrap: false, style: TextStyle(color: Colors.magenta, fontWeight: FontWeight.bold)),
      keys([
        '${g.ud} move ${g.dot} space tick ${g.dot} PgUp/PgDn ${g.dot} Home/End ${g.dot} s all safe ${g.dot} f all ask-first ${g.dot} a all ${g.dot} n none ${g.dot} enter continue ${g.dot} q quit',
        '${g.ud} ${g.dot} space ${g.dot} PgUp/Dn ${g.dot} s safe ${g.dot} f ask ${g.dot} a all ${g.dot} n none ${g.dot} enter ${g.dot} q quit',
        '${g.ud} PgUp/Dn space ${g.dot} s a f n ${g.dot} enter ${g.dot} q quit',
        '${g.ud} space ${g.dot} s a f n ${g.dot} enter ${g.dot} q quit',
        'space s a f n enter q',
      ], t.inner, tag: tag),
    ]);
  }
}

/// The first-run question: set the free-space limits now or later.
class LimitsView extends StatelessComponent {
  const LimitsView({super.key, required this.t, required this.sel, this.g = const {}});
  final Term t;
  final int sel;
  final Map<String, String> g;

  @override
  Component build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tier(['  Set the limits I should watch? They keep a build from starting on a machine that is too full or too busy.', '  Set the limits I should watch?', '  Set the limits?'], t.inner), softWrap: false, style: TextStyle(color: Colors.white)),
        if (t.rows >= 11) for (final l in limitsLines(g, t.inner - 2)) Text('  $l', softWrap: false, style: TextStyle(color: Colors.cyan)),
        SizedBox(height: t.compact ? 0.0 : 1.0),
        choices(t.narrow ? ['Use suggestions', 'Later'] : ['Use my suggestions', "I'll set them later"], sel),
        keys(['${Gl.i.lr} move ${Gl.i.dot} enter choose'], t.inner),
      ]);
}

class ConfirmView extends StatelessComponent {
  const ConfirmView({super.key, required this.t, required this.chosen, required this.cap, required this.sel});
  final Term t;
  final List<Item> chosen;
  final int cap, sel;

  @override
  Component build(BuildContext context) {
    final g = Gl.i, gap = t.compact ? 0.0 : 1.0, shown = chosen.take(cap).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final i in shown) line('  ${size(i.kb).padLeft(6)}  ${fitPath(i.name, t.inner - 10)}', t.inner, color: i.safe ? Colors.green : Colors.yellow),
      if (chosen.length > cap) line('  ...and ${chosen.length - cap} more', t.inner, color: Colors.brightBlack),
      if (chosen.any((i) => !i.safe)) Text(tier(['  Yellow items are shared or costly to regenerate. Read their cost first.', '  Yellow = shared or costly. Read the cost first.', '  Yellow items cost more to rebuild.'], t.inner), softWrap: false, style: TextStyle(color: Colors.yellow)),
      SizedBox(height: gap),
      Text(tier(['  Remove these ${chosen.length} item(s)? A log is written. This cannot be undone.', '  Remove ${chosen.length} item(s)? This cannot be undone.', '  Remove ${chosen.length}? No undo.'], t.inner), softWrap: false, style: TextStyle(color: Colors.white)),
      SizedBox(height: gap),
      choices(['No, go back', 'Yes, remove them'], sel),
      keys(['${g.lr} move ${g.dot} enter choose ${g.dot} esc back ${g.dot} q quit', '${g.lr} ${g.dot} enter ${g.dot} esc back ${g.dot} q quit', '${g.lr} enter esc q'], t.inner),
    ]);
  }
}

class WorkView extends StatelessComponent {
  const WorkView({super.key, required this.t, required this.spin, required this.total, required this.finished, required this.current, required this.results, required this.cap});
  final Term t;
  final String spin, current;
  final int total, finished, cap;
  final List<String> results;

  @override
  Component build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: (t.cols - 8).clamp(10, 60).toDouble(), child: ProgressBar(value: total == 0 ? 0 : finished / total, valueColor: Colors.green, showPercentage: true, fillCharacter: Gl.i.utf ? '█' : '#', emptyCharacter: Gl.i.utf ? '░' : '.')),
        line('  $spin ${current.isEmpty ? 'starting' : 'removing ${fitPath(current, t.inner - 14)}'}', t.inner, color: Colors.cyan),
        for (final r in results.reversed.take(cap)) line('  ${r.startsWith('done') ? Gl.i.check : '!'} ${r.startsWith('done') ? r.split('(').first.trim() : readable(r)}', t.inner, color: r.startsWith('done') ? Colors.green : Colors.yellow),
      ]);
}

class DoneView extends StatelessComponent {
  const DoneView({super.key, required this.t, required this.ran, required this.before, required this.after, required this.manual, this.problems = const []});
  final Term t;
  final int ran, manual;
  final List<String> problems;
  final String before, after;

  @override
  Component build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ProblemLines(t: t, problems: problems),
        if (ran > 0) Text(tier(['  Free space: $before ${Gl.i.to} $after GiB (macOS can take a moment to report it)', '  Free space: $before ${Gl.i.to} $after GiB'], t.inner), softWrap: false, style: TextStyle(color: Colors.brightBlack)),
        if (manual > 0) Text(tier(['  $manual more item${manual == 1 ? '' : 's'} (emulators, SDK files) are left for you to remove by hand. Run: host-hygiene.sh plan', '  $manual more left to remove by hand: host-hygiene.sh plan', '  $manual left by hand: host-hygiene.sh plan'], t.inner), softWrap: false, style: TextStyle(color: Colors.brightBlack)),
        if (!t.compact) SizedBox(height: 1),
        choices(['Quit'], 0),
        keys(doneKeys(), t.inner),
      ]);
}

/// Shown instead of the journey when the terminal is under [Term.minRows] x [Term.minCols].
class TooSmallView extends StatelessComponent {
  const TooSmallView({super.key, required this.t});
  final Term t;

  @override
  Component build(BuildContext context) {
    const need = '${Term.minCols}x${Term.minRows}';
    final msg = tier(['Terminal too small (${t.cols}x${t.rows}). Enlarge to at least $need. q quits.', 'Too small. Need $need. q quits', 'Need $need, q quits', 'q quits'], t.cols);
    return Text(msg, softWrap: false, style: TextStyle(color: Colors.yellow));
  }
}

/// Why something was not removed, word-wrapped (never cut with an ellipsis: the reason is the point). At most [Term.rows] / 4 rows.
class ProblemLines extends StatelessComponent {
  const ProblemLines({super.key, required this.t, required this.problems});
  final Term t;
  final List<String> problems;

  @override
  Component build(BuildContext context) {
    final rows = <String>[], w = (t.inner - 4).clamp(10, 200), cap = (t.rows ~/ 4).clamp(2, 6);
    for (final p in problems.take(3)) {
      var first = true;
      for (final s in wrapSpans(p, w)) { rows.add('${first ? '! ' : '  '}${p.substring(s[0], s[1])}'); first = false; }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final r in rows.take(cap)) Text('  $r', softWrap: false, style: TextStyle(color: Colors.yellow)),
    ]);
  }
}
