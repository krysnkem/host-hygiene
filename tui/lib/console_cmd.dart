// Console look, part 1: the command vocabulary and the table's view model. Pure Dart: no drawing, no I/O, and no way to reach a shell.
import 'engine.dart';

enum Cmd { safe, ask, all, none, sort, filter, look, go, quit, help, empty, error }

class Parsed {
  const Parsed(this.cmd, [this.arg = '', this.error = '']);
  final Cmd cmd;
  final String arg, error;
}

const sortKeys = ['size', 'class', 'path'];
const lookIds = ['guided', 'cockpit', 'dashboard', 'spacemap', 'console', 'plain'];
const maxInput = 40;
const _plain = {'safe': Cmd.safe, 'ask': Cmd.ask, 'all': Cmd.all, 'none': Cmd.none, 'go': Cmd.go, 'quit': Cmd.quit, 'q': Cmd.quit, 'help': Cmd.help};

/// One typed line (with or without the leading ':') to a command. Anything outside the fixed vocabulary is an error, never an action.
Parsed parseCommand(String raw) {
  var t = raw.trim();
  if (t.startsWith(':')) t = t.substring(1).trim();
  if (t.isEmpty) return const Parsed(Cmd.empty);
  if (t.runes.any((r) => r < 32 || r == 127)) return const Parsed(Cmd.error, '', 'control characters are not allowed');
  final sp = t.indexOf(RegExp(r'\s')), verb = (sp < 0 ? t : t.substring(0, sp)).toLowerCase(), arg = sp < 0 ? '' : t.substring(sp).trim();
  final c = _plain[verb];
  if (c != null) return arg.isEmpty ? Parsed(c) : Parsed(Cmd.error, '', ':$verb takes no argument');
  if (verb == 'sort') {
    return sortKeys.contains(arg.toLowerCase()) ? Parsed(Cmd.sort, arg.toLowerCase()) : const Parsed(Cmd.error, '', 'usage: :sort size|class|path');
  }
  if (verb == 'look') return lookIds.contains(arg.toLowerCase()) ? Parsed(Cmd.look, arg.toLowerCase()) : Parsed(Cmd.error, '', 'usage: :look ${lookIds.join('|')}');
  if (verb == 'filter') return Parsed(Cmd.filter, arg);
  final shown = verb.length > 16 ? '${verb.substring(0, 16)}...' : verb;
  return Parsed(Cmd.error, '', 'unknown command :$shown (:help lists them)');
}

/// What the console remembers between frames. One instance: there is one screen.
class ConsoleModel {
  String sortKey = '', filter = '', buf = '', msg = '';
  bool desc = true, typing = false, help = false, err = false;
  int vtop = 0;
  void say(String m, {bool bad = false}) { msg = m; err = bad; }
}

final cm = ConsoleModel();

bool defaultDesc(String key) => key == 'size';

bool matches(Item i, String f) {
  if (f.isEmpty) return true;
  final q = f.toLowerCase(), cls = !i.supported ? 'manual' : (i.safe ? 'safe' : 'ask');
  return i.name.toLowerCase().contains(q) || i.id.toLowerCase().contains(q) || cls.contains(q);
}

/// Indexes into [items] of the rows that pass [filter], in list order.
List<int> visibleIdx(List<Item> items, String filter) => [for (var i = 0; i < items.length; i++) if (matches(items[i], filter)) i];

/// Position in [vis] of the row the cursor [cur] is on, or the next visible one (the last when none follows). -1 when nothing is visible.
int visPos(List<int> vis, int cur) {
  if (vis.isEmpty) return -1;
  final p = vis.indexWhere((x) => x >= cur);
  return p < 0 ? vis.length - 1 : p;
}

/// Stable in-place sort by size, class (safe, ask, manual) or path.
void sortItems(List<Item> l, String key, bool desc) {
  final at = {for (var i = 0; i < l.length; i++) l[i]: i};
  int rank(Item i) => !i.supported ? 2 : (i.safe ? 0 : 1);
  l.sort((a, b) {
    var c = key == 'size' ? a.kb.compareTo(b.kb) : key == 'class' ? rank(a).compareTo(rank(b)) : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (desc) c = -c;
    return c != 0 ? c : at[a]!.compareTo(at[b]!);
  });
}
