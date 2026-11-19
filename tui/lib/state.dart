// The one state every look draws and every key press changes. No drawing and no I/O in here.
import 'engine.dart';
import 'home_model.dart';
import 'layout.dart';
import 'perf_model.dart';

enum Stage { look, limits, pick, confirm, work, done }

class AppState {
  Stage stage = Stage.look;
  String lookId = 'guided';
  int tick = 0, sel = 0, cur = 0, top = 0;
  // data
  Map<String, String> g = {};
  Profile? profile;
  List<Item> items = [], chosen = [];
  String mood = 'calm';
  /// A one-line result shown in the key hints (e.g. after `V` saved the look); cleared by the next key.
  String note = '';
  /// The look chooser is open ([pickFirst]: the first-run question). [askLook]: the question has not been answered yet.
  /// The hello and the name question (first run, before the look question).
  bool onboarding = false, askScan = false;
  /// The Memory or CPU screen when one is open.
  Resource? screen;
  /// Home: shown first once the machine is read (HH_HOME=0 skips it). [homeSel] is the highlighted row, [homeNote] one line of explanation.
  bool home = false, homeOn = true;
  int homeSel = 0, ignoredCount = 0;
  String homeNote = '';
  /// The Alarms or Settings form when one is open, and its highlighted row.
  Area? form;
  int formSel = 0;
  Reading? reading;
  String userName = '';
  bool picking = false, pickFirst = false, askLook = false;
  // work progress
  String freeBefore = '', freeAfter = '', freed = '', current = '';
  int total = 0, finished = 0, ran = 0, freedKb = 0;
  final results = <String>[], problems = <String>[];
  // speech (typed out by the mascot; a look that does not speak sets [speaks] false)
  bool speaks = true;
  List<String> lines = [];
  int lineIdx = 0, charIdx = 0, pause = 0;

  bool get speechDone => !speaks || lineIdx >= lines.length;
  /// Disk figures a look may show: what is ticked, and what the plan found.
  int get selectedKb => items.where((i) => i.on).fold(0, (s, i) => s + i.kb);
  int get totalKb => items.fold(0, (s, i) => s + i.kb);

  void say(List<String> l) { lines = l; lineIdx = 0; charIdx = 0; pause = 0; sel = 0; }
  /// Keep the cursor inside a window of [win] rows.
  void fit(int win) { if (cur >= top + win) top = cur - win + 1; if (cur < top) top = cur; if (top < 0) top = 0; }
  void move(int to, int win) { cur = to.clamp(0, items.length - 1); fit(win); }
  /// One typed-speech step per timer tick.
  void advance(int win) {
    tick++; fit(win);
    if (speechDone) return;
    charIdx += 2;
    if (charIdx >= lines[lineIdx].length) { if (++pause > 10) { lineIdx++; charIdx = 0; pause = 0; } }
  }
}

/// Mascot lines typed so far, wrapped to [w] columns. [pad] holds the final height so the layout does not jump while typing; [last] keeps only the newest rows.
List<String> spokenLines(AppState s, int w, {int pad = 0, int last = 0}) {
  final out = <String>[];
  for (var i = 0; i < s.lines.length && i <= s.lineIdx; i++) {
    final done = i < s.lineIdx || s.speechDone, l = s.lines[i], n = done ? l.length : s.charIdx.clamp(0, l.length);
    final start = out.length;
    for (final sp in wrapSpans(l, w)) { if (n > sp[0] || sp[0] == 0) out.add(l.substring(sp[0], n < sp[1] ? n : sp[1])); }
    if (!done) { if (out.length == start) out.add(''); out[out.length - 1] += Gl.i.cursor; }
  }
  if (last > 0) return out.sublist(out.length > last ? out.length - last : 0);
  while (out.length < pad) { out.add(''); }
  return out;
}
