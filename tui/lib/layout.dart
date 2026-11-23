// Terminal size, glyph set and text fitting. Everything here is pure so it can be reasoned about without a terminal.
import 'dart:io';

/// Rows and columns read fresh each frame so a resize takes effect at once.
class Term {
  Term()
      : rows = _dim(() => stdout.terminalLines, 30),
        cols = _dim(() => stdout.terminalColumns, 100);
  final int rows, cols;
  static int _dim(int Function() f, int dflt) {
    try { return stdout.hasTerminal ? f() : dflt; } catch (_) { return dflt; }
  }
  /// Under 10 rows: drop the stepper and the mascot so the list keeps room.
  bool get tiny => rows < 10;
  /// Under 24 rows: no blank lines, mascot without a border.
  bool get compact => rows < 24;
  bool get narrow => cols < 56;
  /// Below this nothing useful fits: show one message instead of a broken layout.
  static const minRows = 6, minCols = 30;
  bool get tooSmall => rows < minRows || cols < minCols;
  /// Width of the mascot's speech area (face column and borders taken off).
  int get speechW => (cols - (compact ? 14 : 18)).clamp(10, 200);
  int get inner => (cols - 4).clamp(10, 300);
}

/// Glyphs: Unicode when the locale says UTF-8, plain ASCII otherwise (or when HH_ASCII=1).
class Gl {
  Gl._(this.utf);
  static final Gl i = Gl._(_detect());
  final bool utf;
  static bool _detect() {
    final e = Platform.environment;
    if (e['HH_ASCII'] == '1') return false;
    final v = [e['LC_ALL'], e['LC_CTYPE'], e['LANG']].firstWhere((x) => x != null && x.isNotEmpty, orElse: () => '')!.toLowerCase();
    return v.contains('utf-8') || v.contains('utf8');
  }
  String get arrow => utf ? '❯' : '>';
  String get check => utf ? '✓' : 'v';
  String get heavy => utf ? '━━━' : '===';
  String get light => utf ? '───' : '---';
  String get cursor => utf ? '▌' : '_';
  String get ellipsis => utf ? '…' : '...';
  String get dot => utf ? '·' : '|';
  String get ud => utf ? '↑↓' : 'up/dn';
  String get lr => utf ? '← →' : '<- ->';
  String get left => utf ? '←' : '<-';
  String get right => utf ? '→' : '->';
  String get up => utf ? '↑' : '^';
  String get down => utf ? '↓' : 'v';
  String get to => utf ? '→' : '->';
  List<String> get spin => utf ? ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'] : ['|', '/', '-', '\\', '|', '/', '-', '\\', '|', '/'];
  String face(String k) {
    if (utf) {
      return const {'work0': '(•‿•)', 'work1': '(•ᴗ•)', 'work2': '(•‿•)', 'work3': '(°‿°)', 'done': '(^ᴗ^)', 'stop': '(°o°)', 'tight': '(•_•)', 'calm': '(•ᴗ•)', 'blink': '(-ᴗ-)'}[k]!;
    }
    return const {'work0': '(o_o)', 'work1': '(o.o)', 'work2': '(o_o)', 'work3': '(O_O)', 'done': '(^_^)', 'stop': '(O_O)', 'tight': '(o_o)', 'calm': '(o_o)', 'blink': '(-_-)'}[k]!;
  }
}

/// Terminal cells one rune takes: 0 for combining marks, 2 for CJK and emoji, else 1.
int runeCells(int r) {
  if (r == 0x200D || r == 0xFE0F || (r >= 0x300 && r <= 0x36F)) return 0;
  if ((r >= 0x1100 && r <= 0x115F) || (r >= 0x2E80 && r <= 0xA4CF) || (r >= 0xAC00 && r <= 0xD7A3) || (r >= 0xF900 && r <= 0xFAFF) ||
      (r >= 0xFE30 && r <= 0xFE6F) || (r >= 0xFF00 && r <= 0xFF60) || (r >= 0xFFE0 && r <= 0xFFE6) || (r >= 0x1F300 && r <= 0x1F64F) ||
      (r >= 0x1F680 && r <= 0x1F6FF) || (r >= 0x1F900 && r <= 0x1F9FF) || (r >= 0x20000 && r <= 0x3FFFD)) { return 2; }
  return 1;
}

/// Width of [s] in terminal cells.
int cells(String s) => s.runes.fold(0, (n, r) => n + runeCells(r));

/// The longest run of [r] (from the front, or the back when [fromEnd]) that fits [w] cells.
List<int> _take(List<int> r, int w, {bool fromEnd = false}) {
  final out = <int>[];
  var n = 0;
  for (final x in fromEnd ? r.reversed : r) {
    final c = runeCells(x);
    if (n + c > w) break;
    n += c; out.add(x);
  }
  return fromEnd ? out.reversed.toList() : out;
}

/// Cuts [s] to [w] cells with a trailing ellipsis.
String fit(String s, int w) {
  if (cells(s) <= w) return s;
  final r = s.runes.toList(), e = Gl.i.ellipsis;
  if (w <= e.length) return String.fromCharCodes(_take(r, w < 0 ? 0 : w));
  return String.fromCharCodes(_take(r, w - e.length)) + e;
}

/// Cuts a path in the middle so both the start and the file name survive.
String fitPath(String s, int w) {
  if (cells(s) <= w) return s;
  final r = s.runes.toList(), e = Gl.i.ellipsis;
  if (w <= e.length + 2) return fit(s, w);
  final keep = w - e.length, head = (keep * 0.4).floor();
  return String.fromCharCodes(_take(r, head)) + e + String.fromCharCodes(_take(r, keep - head, fromEnd: true));
}

/// First of [tiers] that fits [w]; the last one is cut with an ellipsis when none do.
String tier(List<String> tiers, int w) {
  for (final t in tiers) { if (cells(t) <= w) return t; }
  return fit(tiers.last, w);
}

/// Greedy word wrap into [start, end) spans of [s], so typed-out text can reveal span by span.
List<List<int>> wrapSpans(String s, int w) {
  final out = <List<int>>[];
  var start = 0;
  while (start < s.length) {
    var end = start + w;
    if (end >= s.length) { out.add([start, s.length]); break; }
    final sp = s.lastIndexOf(' ', end);
    if (sp > start) { out.add([start, sp]); start = sp + 1; }
    else { out.add([start, end]); start = end; }
  }
  if (out.isEmpty) out.add([0, 0]);
  return out;
}
