// Key handling, the work run and the first look: shared by every look. It changes AppState and asks for a redraw; it never draws.
import 'dart:async';
import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'engine.dart';
import 'focus.dart';
import 'home_keys.dart';
import 'home_model.dart';
import 'layout.dart';
import 'look.dart';
import 'perf_model.dart';
import 'state.dart';
import 'typesay.dart';
import 'ui.dart' show menuAfterDone;
import 'voice.dart';

class Controller {
  Controller(this.s, this.redraw);
  final AppState s;
  /// Runs [f], then redraws (the host's setState).
  final void Function(void Function()) redraw;
  final eng = Engine();
  static final minMb = int.tryParse(Platform.environment['HH_MIN_MB'] ?? '') ?? 50;

  Look get want => lookFor(s.lookId);
  Look get look => fitLook(want, Term());
  int get win => look.listRows(s, Term());
  void advance() => s.advance(win);
  void _move(int to) => s.move(to, win);

  /// Wheel scrolls the pick list by three rows, the cursor going with it.
  void wheel(MouseEvent e) {
    if (s.stage != Stage.pick || s.items.isEmpty || !e.pressed) return;
    if (e.button == MouseButton.wheelDown) { redraw(() => _move(s.cur + 3)); }
    else if (e.button == MouseButton.wheelUp) { redraw(() => _move(s.cur - 3)); }
  }

  /// Click: put the cursor on the row and tick it.
  void click(int i) => redraw(() { s.cur = i; s.fit(win); if (s.items[i].supported) s.items[i].on = !s.items[i].on; });

  /// Completes when the first-run look question is answered; start() waits on it before scanning.
  Completer<void>? lookAnswered, onboarded, scanAnswered;

  Future<void> start() async {
    s.say([pick(hello)]);
    s.lookId = lookFor(await eng.ui()).id; s.speaks = want.speaks;
    final fenv = Platform.environment['HH_FOCUS'] ?? '', focus = fenv == '1' || fenv.startsWith('perf');
    if (fenv.startsWith('perf')) redraw(() => s.screen = fenv == 'perf-cpu' ? Resource.cpu : Resource.memory);
    s.askLook = !focus && Platform.environment['HH_NO_PROMPT'] != '1' && !looks.any((l) => l.id == eng.uiInFile);
    // First run: the look question comes before anything is scanned, so no work is spent behind it.
    final firstRun = s.askLook;
    if (s.askLook) { final hi = Completer<void>(); onboarded = hi; redraw(() => s.onboarding = true); await hi.future; }
    if (s.askLook) { final done = lookAnswered = Completer<void>(); redraw(() { s.picking = true; s.pickFirst = true; }); await done.future; }
    if (firstRun) { final go = scanAnswered = Completer<void>(); redraw(() => s.askScan = true); await go.future; }
    final r = await Future.wait([eng.profile(), eng.guard(), eng.plan(minMb), eng.reading()]);
    final p = r[0] as Profile; s.g = r[1] as Map<String, String>; s.items = r[2] as List<Item>; s.profile = p; s.reading = r[3] as Reading; refreshIgnored();
    s.homeOn = Platform.environment['HH_HOME'] != '0' && fenv != '1'; menuAfterDone = s.homeOn;
    final g = s.g, items = s.items;
    final fl = fenv == '1' ? focusTick(items, g) : null;
    s.mood = g['status'] == 'stop' ? 'stop' : (g['status'] == 'low' ? 'tight' : 'calm');
    final out = <String>[s.userName.isEmpty ? pick(hello) : 'Thanks, ${s.userName}. Give me a moment to look around your machine.'];
    TypeSaid? ts;
    if (p.kind == 'non-developer' || (p.kinds.isEmpty && p.projects.isEmpty)) { out.add(pick(nonDev)); }
    else { ts = sayTypes(p); out.add(ts.line); }
    const label = {'android': 'the Android SDK', 'xcode': 'Xcode', 'gradle': 'Gradle', 'docker': 'Docker', 'fvm': 'FVM', 'rust': 'Rust', 'brew': 'Homebrew', 'node': 'Node.js', 'go': 'Go', 'ruby': 'a Ruby version manager', 'php': 'Composer', 'dotnet': '.NET', 'kmp': 'Kotlin/Native'};
    const covers = {'rust': ['rust'], 'node': ['node', 'rn', 'frontend'], 'go': ['go'], 'ruby': ['ruby', 'rails'], 'php': ['php'], 'dotnet': ['dotnet', 'maui'], 'kmp': ['kmp']};
    final have = [for (final t in p.tools) if (label.containsKey(t) && !(covers[t] ?? const []).any((c) => ts?.named.contains(c) ?? false)) label[t]!];
    if (have.isNotEmpty) out.add(fill(pick(tools), {'t': joinAnd(have)}));
    out.add(fill(pick(state), {'f': g['free_gb'] ?? '?', 'l': g['load'] ?? '?'}));
    final safe = items.where((i) => i.safe && i.supported).toList(), ask = items.where((i) => !i.safe && i.supported).toList();
    out.add(safe.isEmpty && ask.isNotEmpty ? fill(pick(askOnly), {'n': '${ask.length} item${ask.length == 1 ? '' : 's'} (${size(ask.fold(0, (n, i) => n + i.kb))})'}) : safe.isEmpty ? pick(spotless) : fill(pick(found), {'n': '${safe.length} item${safe.length == 1 ? '' : 's'} (${size(safe.fold(0, (n, i) => n + i.kb))})'}));
    if (s.mood == 'tight') out.add(pick(tight)); if (s.mood == 'stop') out.add(pick(stopLines));
    redraw(() { s.say(fl ?? out); final ready = eng.configExists || focus; s.stage = ready ? Stage.pick : Stage.limits; if (!items.any((i) => i.supported) && ready) s.stage = Stage.done; s.home = ready && s.homeOn; });
  }

  void _quit() => shutdownApp();

  /// Home keys; ESC and q leave the tool from Home.
  bool homeKey(KeyboardEvent k) => handleHomeKey(s, k, redraw, rescan: _rescan, look: (save) => _switch(save: save), quit: _quit, enterStorage: _enterStorage);
  /// Coming back to Storage after a clear shows the refreshed pick list, not the old result.
  void _enterStorage() { if (s.stage == Stage.done && s.items.any((i) => i.supported)) { s.stage = Stage.pick; s.cur = 0; s.top = 0; s.say([pick(asking)]); } }
  Future<void> _rescan() async { final r = await eng.reading(); redraw(() { s.reading = r; s.homeNote = ''; }); refreshIgnored(); }
  /// Keeps the Settings line on Home honest after an ignore or a restore.
  Future<void> refreshIgnored() async { final n = (await eng.ignored()).length; redraw(() => s.ignoredCount = n); }

  /// `v` cycles the five designs live (skipping any too big for this terminal); `V` also saves the new look as the default. Cursor, ticks and stage are untouched: they live in AppState, not in a look.
  void _switch({required bool save}) {
    final to = nextLook(s.lookId, Term());
    if (to == null) { redraw(() => s.note = '* no other look fits this size'); return; }
    redraw(() { s.lookId = to.id; s.speaks = to.speaks; s.note = save ? '* saving...' : ''; });
    if (save) eng.setUi(to.id).then((ok) => redraw(() => s.note = ok ? '* saved ${to.name} as the default look' : '* could not save the default look'));
  }

  bool key(KeyboardEvent k) {
    if (look.onKey(s, k, redraw)) return true;
    final lk = k.logicalKey, items = s.items;
    if (s.note.isNotEmpty) redraw(() => s.note = '');
    if (s.stage == Stage.work) return true;
    if (lk == LogicalKey.escape && s.homeOn && (s.stage == Stage.pick || s.stage == Stage.done)) { redraw(() { s.home = true; s.homeNote = ''; }); return true; }
    if (lk == LogicalKey.keyM && !k.isControlPressed && s.stage != Stage.limits) { redraw(() => s.screen = Resource.memory); return true; }
    if (lk == LogicalKey.keyC && !k.isControlPressed && s.stage != Stage.limits) { redraw(() => s.screen = Resource.cpu); return true; }
    if (lk == LogicalKey.keyL && !k.isControlPressed && s.stage != Stage.limits) { redraw(() { s.picking = true; s.pickFirst = false; }); return true; }
    if (lk == LogicalKey.keyV && !k.isControlPressed && s.stage != Stage.limits) { _switch(save: k.character == 'V' || k.isShiftPressed); return true; }
    if (lk == LogicalKey.keyQ && Term().tooSmall) { _quit(); return true; }
    if (lk == LogicalKey.keyQ && s.stage != Stage.limits) { _quit(); return true; }
    if (!s.speechDone && lk == LogicalKey.enter && (s.stage == Stage.look || s.stage == Stage.limits)) { redraw(() { s.lineIdx = s.lines.length; }); return true; }
    switch (s.stage) {
      case Stage.limits:
        if (!s.speechDone) return false;
        if (lk == LogicalKey.arrowLeft || lk == LogicalKey.arrowRight) { redraw(() => s.sel = 1 - s.sel); return true; }
        if (lk == LogicalKey.enter) {
          () async { if (s.sel == 0) await eng.setLimits(15, 5, 8); redraw(() { s.stage = items.any((i) => i.supported) ? Stage.pick : Stage.done; s.say([pick(asking)]); s.home = s.homeOn; }); }();
          return true;
        }
      case Stage.pick:
        final vis = items;
        if (vis.isNotEmpty) {
          final jump = (win - 1).clamp(1, 60);
          if (lk == LogicalKey.arrowDown) { redraw(() => _move(s.cur + 1)); return true; }
          if (lk == LogicalKey.arrowUp) { redraw(() => _move(s.cur - 1)); return true; }
          if (lk == LogicalKey.pageDown) { redraw(() => _move(s.cur + jump)); return true; }
          if (lk == LogicalKey.pageUp) { redraw(() => _move(s.cur - jump)); return true; }
          if (lk == LogicalKey.home) { redraw(() => _move(0)); return true; }
          if (lk == LogicalKey.end) { redraw(() => _move(vis.length - 1)); return true; }
          if (lk == LogicalKey.space && vis[s.cur].supported) { redraw(() => vis[s.cur].on = !vis[s.cur].on); return true; }
        }
        if (lk == LogicalKey.keyS) { redraw(() { for (final i in vis) { i.on = i.safe && i.supported; } }); return true; }
        if (lk == LogicalKey.keyF) { redraw(() { for (final i in vis) { i.on = !i.safe && i.supported; } }); return true; }
        if (lk == LogicalKey.keyA) { redraw(() { for (final i in vis) { i.on = i.supported; } }); return true; }
        if (lk == LogicalKey.keyN) { redraw(() { for (final i in vis) { i.on = false; } }); return true; }
        if (lk == LogicalKey.enter && items.any((i) => i.on)) { redraw(() { s.chosen = items.where((i) => i.on).toList(); s.stage = Stage.confirm; s.sel = 0; s.say(['Here is what you chose. ${pick(asking)}']); }); return true; }
      case Stage.confirm:
        if (lk == LogicalKey.arrowLeft || lk == LogicalKey.arrowRight) { redraw(() => s.sel = 1 - s.sel); return true; }
        if (lk == LogicalKey.escape) { redraw(() { s.stage = Stage.pick; s.say([pick(asking)]); }); return true; }
        if (lk == LogicalKey.enter) { if (s.sel == 1) { _work(); } else { redraw(() { s.stage = Stage.pick; s.say([pick(asking)]); }); } return true; }
      case Stage.done:
        if (lk == LogicalKey.enter) { if (s.homeOn) { redraw(() { s.home = true; s.homeNote = ''; }); } else { _quit(); } return true; }
      default:
    }
    return false;
  }

  Future<void> _work() async {
    s.freedKb = 0;
    s.g = await eng.guard(); s.freeBefore = s.g['free_gb'] ?? '?';
    redraw(() { s.stage = Stage.work; s.total = s.chosen.length; s.finished = 0; s.ran = 0; s.results.clear(); s.problems.clear(); s.current = ''; s.freed = ''; s.say([pick(working)]); });
    final re = RegExp(r'^\[(\d+)/(\d+)\]\s+(\S+)\s+(.*)$');
    await for (final l in eng.apply(s.chosen)) {
      final m = re.firstMatch(l);
      if (m != null) {
        final what = m.group(3)!;
        redraw(() {
          if (what == 'removing') { s.current = m.group(4)!.replaceAll(RegExp(r'^\S+\s+'), '').replaceAll(RegExp(r'\s*\.\.\.$'), ''); }
          else {
            s.finished = int.parse(m.group(1)!); final r = l.replaceFirst(RegExp(r'^\[\d+/\d+\]\s+'), ''); s.results.add(r);
            if (what == 'done') { s.ran++; s.freedKb += parseSize(RegExp(r'freed (\S+) measured').firstMatch(r)?.group(1) ?? ''); }
            else { s.problems.add(readable(r)); }
          }
        });
      } else if (l.startsWith('stopping on')) { /* the REFUSED line above already says why */ }
      final r = RegExp(r'ran (\d+) item\(s\), freed (\S+)').firstMatch(l);
      if (r != null) redraw(() { s.ran = int.parse(r.group(1)!); s.freed = r.group(2)!; });
    }
    if (s.freed.isEmpty && s.ran > 0) s.freed = size(s.freedKb);
    s.g = await eng.guard(); s.freeAfter = s.g['free_gb'] ?? '?';
    final again = await eng.plan(minMb), fresh = await eng.reading();
    redraw(() {
      s.items = again; s.reading = fresh; s.stage = Stage.done; s.cur = 0; s.top = 0;
      s.say([(s.ran > 0 ? 'Done. I cleared ${s.freed} across ${s.ran} item${s.ran == 1 ? '' : 's'}.' : 'Nothing was removed.') + (s.problems.isNotEmpty ? ' Some items were left alone, see below.' : ''), if (s.problems.isEmpty && s.ran > 0) pick(doneLines)]);
    });
  }
}
