// Console look, part 2: the key hook. In the pick stage it owns navigation, the sort keys and the ':' command line; everything else falls through to the shared controller.
import 'package:nocterm/nocterm.dart';
import 'console_cmd.dart';
import 'engine.dart';
import 'layout.dart';
import 'look.dart';
import 'state.dart';

typedef Redraw = void Function(void Function());

bool consoleKey(AppState s, KeyboardEvent k, Redraw redraw, int win) {
  if (s.stage != Stage.pick || s.items.isEmpty) return false;
  final lk = k.logicalKey, ch = k.character;
  if (cm.typing) {
    if (k.isControlPressed && lk == LogicalKey.keyC) return false;
    redraw(() => _type(s, k, win));
    return true;
  }
  if (cm.help) { redraw(() => cm.help = false); return true; }
  cm.msg = '';
  if (lk == LogicalKey.colon || ch == ':') { redraw(() { cm.typing = true; cm.buf = ''; }); return true; }
  if (lk == LogicalKey.slash || ch == '/') { redraw(() { cm.typing = true; cm.buf = 'filter '; }); return true; }
  final sort = lk == LogicalKey.keyZ ? 'size' : lk == LogicalKey.keyC ? 'class' : lk == LogicalKey.keyP ? 'path' : null;
  if (sort != null && !k.isControlPressed) { redraw(() => _sort(s, sort, toggle: true)); return true; }
  final vis = visibleIdx(s.items, cm.filter), pos = visPos(vis, s.cur), jump = (win - 1).clamp(1, 60);
  if (vis.isEmpty) return false;
  int? to = lk == LogicalKey.arrowDown ? pos + 1 : lk == LogicalKey.arrowUp ? pos - 1 : lk == LogicalKey.pageDown ? pos + jump : lk == LogicalKey.pageUp ? pos - jump : lk == LogicalKey.home ? 0 : lk == LogicalKey.end ? vis.length - 1 : null;
  if (to != null) { redraw(() { s.cur = vis[to.clamp(0, vis.length - 1)]; }); return true; }
  if (lk == LogicalKey.space) { redraw(() { s.cur = vis[pos]; if (s.items[s.cur].supported) s.items[s.cur].on = !s.items[s.cur].on; }); return true; }
  return false;
}

void _type(AppState s, KeyboardEvent k, int win) {
  final lk = k.logicalKey, ch = k.character;
  if (lk == LogicalKey.escape) { cm.typing = false; cm.buf = ''; return; }
  if (lk == LogicalKey.enter) { final line = cm.buf; cm.typing = false; cm.buf = ''; _run(s, parseCommand(line)); return; }
  if (lk == LogicalKey.backspace) {
    if (cm.buf.isEmpty) { cm.typing = false; return; }
    final r = cm.buf.runes.toList()..removeLast();
    cm.buf = String.fromCharCodes(r);
    return;
  }
  if (ch != null && ch.isNotEmpty && !k.isControlPressed && !ch.runes.any((r) => r < 32 || r == 127) && cells(cm.buf) + cells(ch) <= maxInput) cm.buf += ch;
}

void _sort(AppState s, String key, {bool toggle = false}) {
  final cur = s.items.isEmpty ? null : s.items[s.cur];
  cm.desc = toggle && cm.sortKey == key ? !cm.desc : defaultDesc(key);
  cm.sortKey = key;
  sortItems(s.items, key, cm.desc);
  if (cur != null) s.cur = s.items.indexOf(cur).clamp(0, s.items.length - 1);
}

void _tickOnly(AppState s, bool Function(Item) want, String what) {
  for (final i in s.items) { i.on = i.supported && want(i); }
  final n = s.items.where((i) => i.on);
  if (n.isEmpty) { cm.say('all ticks cleared'); return; }
  cm.say('ticked ${n.length} $what (${size(n.fold(0, (a, i) => a + i.kb))})');
}

void _run(AppState s, Parsed p) {
  switch (p.cmd) {
    case Cmd.empty: break;
    case Cmd.error: cm.say(p.error, bad: true);
    case Cmd.safe: _tickOnly(s, (i) => i.safe, 'safe');
    case Cmd.ask: _tickOnly(s, (i) => !i.safe, 'ask-first');
    case Cmd.all: _tickOnly(s, (i) => true, 'in all');
    case Cmd.none: _tickOnly(s, (i) => false, 'in all');
    case Cmd.sort: _sort(s, p.arg); cm.say('sorted by ${p.arg}');
    case Cmd.help: cm.help = true;
    case Cmd.look: _look(s, p.arg);
    case Cmd.quit: shutdownApp();
    case Cmd.filter:
      cm.filter = p.arg; cm.vtop = 0;
      final vis = visibleIdx(s.items, p.arg);
      if (vis.isNotEmpty) s.cur = vis[visPos(vis, s.cur)];
      cm.say(p.arg.isEmpty ? 'filter cleared' : 'filter "${p.arg}": ${vis.length} of ${s.items.length} rows');
    case Cmd.go:
      if (!s.items.any((i) => i.on)) { cm.say('nothing ticked: try :safe, :ask or space', bad: true); break; }
      s.chosen = s.items.where((i) => i.on).toList(); s.stage = Stage.confirm; s.sel = 0;
  }
}

/// `:look <id>`: the typed twin of the `v` key, which is text while the prompt is open. Like `v` it does not save.
void _look(AppState s, String id) {
  final to = lookFor(id);
  if (to.id != id) { cm.say('no look named $id', bad: true); return; }
  if (!fits(to, Term())) { final (c, r) = minSize(to); cm.say('${to.name} needs ${c}x$r', bad: true); return; }
  s.lookId = id; s.speaks = to.speaks;
}
