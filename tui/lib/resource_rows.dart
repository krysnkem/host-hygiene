// The text of the Memory and CPU screens: pure functions, so they can be tested without a terminal.
import 'advice_text.dart';
import 'home_model.dart';
import 'perf_model.dart';

String resourceTitle(Resource r) => r == Resource.cpu ? 'CPU' : 'Memory';

/// "Memory: 31% free, your line is 15% (ok)". [rd] null means the reading is still loading or failed.
String headerText(Resource r, Reading? rd) {
  if (rd == null) return '${resourceTitle(r)}: reading...';
  final word = const {Level.ok: 'ok', Level.warn: 'LOW', Level.crit: 'CRITICAL'}[rd.levelFor(r)] ?? '';
  if (r == Resource.cpu) {
    if (rd.load == null) return 'CPU: could not read the load just now';
    return 'CPU: load ${rd.load}${rd.cores == null ? '' : ' on ${rd.cores} cores'}, your max is ${rd.maxLoad ?? '?'}${word.isEmpty ? '' : ' ($word)'}';
  }
  if (rd.memFreePct == null) return 'Memory: could not read it just now';
  return 'Memory: ${rd.memFreePct}% free, your line is ${rd.memLinePct ?? 15}%${word.isEmpty ? '' : ' ($word)'}';
}

/// "Alarm snoozed until Mon 15:46", or empty when it is not snoozed. [now] is for tests.
String snoozeText(Resource r, Reading? rd, {DateTime? now}) {
  final u = rd?.snoozedUntil(r), n = now ?? DateTime.now();
  if (u == null || !u.isAfter(n)) return '';
  const d = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String two(int v) => v.toString().padLeft(2, '0');
  final same = u.year == n.year && u.month == n.month && u.day == n.day;
  return 'Alarm snoozed until ${same ? '' : '${d[u.weekday - 1]} '}${two(u.hour)}:${two(u.minute)}. z again to change it.';
}

/// One list row: tick box, rank, name, processes, memory, CPU, kind.
String rowText(AppRow a, bool ticked, int nameW, int i) {
  final box = a.system ? '   ' : (ticked ? '[x]' : '[ ]');
  return '$box ${(i + 1).toString().padLeft(2)}  ${_fit(a.name, nameW).padRight(nameW)} ${a.procs.toString().padLeft(4)} ${mem(a.mb).padLeft(8)} ${('${a.cpu.toStringAsFixed(0)}%').padLeft(5)}  ${a.kind}';
}

String _fit(String s, int w) => s.length <= w ? s : '${s.substring(0, w - 1)}…';

/// The line under the list: what ticking frees, or a hint when nothing is ticked.
String tallyText(Resource r, List<AppRow> ticked) {
  final t = ticked.where((a) => !a.system).toList();
  if (t.isEmpty) return 'Tick the apps you plan to close to see what that would free. hh never closes anything for you.';
  return r == Resource.cpu ? 'Ticked ${t.length}: closing them would free about ${freedCpu(t).toStringAsFixed(0)}% of a core.' : 'Ticked ${t.length}: closing them would free about ${mem(freedMb(t))}.';
}

/// The directions for the selected row, as one paragraph (empty when there is no row).
String directionsText(AppRow? a) => a == null ? '' : '${a.name}: ${directions(a).join(' ')}';
