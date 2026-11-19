// The view seam: a Look draws an AppState and nothing else. Keys, timers and data live in control.dart and state.dart.
import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'cockpit_look.dart';
import 'console_look.dart';
import 'dashboard_look.dart';
import 'guided_look.dart';
import 'layout.dart';
import 'plain_look.dart';
import 'spacemap_look.dart';
import 'state.dart';

/// What a look may ask of the app besides reading the state.
class Actions {
  const Actions({required this.tap});
  final void Function(int row) tap;
}

abstract class Look {
  const Look();
  /// Config value (`ui=`), `HH_LOOK` value and the name shown to people.
  String get id;
  String get name;
  /// Smaller than this and the app draws the plain look with a hint instead of clipping this one.
  int get minCols;
  int get minRows;
  /// False for a look that has no mascot, so no speech is typed out for it.
  bool get speaks => true;
  /// Key hook, called before the shared key handling. Return true when the look used the key (a text prompt, its own sort keys). Most looks leave this alone.
  bool onKey(AppState s, KeyboardEvent k, void Function(void Function()) redraw) => false;
  /// How many pick-list rows fit under this look's chrome.
  int listRows(AppState s, Term t);
  Component build(AppState s, Term t, Actions act);
}

const guided = GuidedLook(), plain = PlainLook(), cockpit = CockpitLook(), dashboard = DashboardLook(), spacemap = SpaceMapLook(), console = ConsoleLook();
/// Every look that can be chosen (the same ids as UI_LOOKS in host-hygiene.sh).
const List<Look> looks = [guided, plain, cockpit, dashboard, spacemap, console];
/// What the `v` key cycles through. Plain is the fallback, never a stop.
const List<Look> cycle = [guided, cockpit, dashboard, spacemap, console];

/// The look for a config/env id; anything unknown or empty is the guided one.
Look lookFor(String? id) => looks.firstWhere((l) => l.id == id, orElse: () => guided);

/// The key-hint fragment for the switch key; a fresh `V` shows what it saved instead.
String lookKey(AppState s) => s.note.isNotEmpty ? s.note : 'v look: ${lookFor(s.lookId).name} ${Gl.i.dot} L choose ${Gl.i.dot} m apps';

/// The smallest size [l] accepts (`HH_LOOK_MIN=COLSxROWS` raises it for any look but plain; test hook).
(int, int) minSize(Look l) {
  final m = RegExp(r'^(\d+)x(\d+)$').firstMatch(Platform.environment['HH_LOOK_MIN'] ?? '');
  return m == null ? (l.minCols, l.minRows) : (int.parse(m.group(1)!), int.parse(m.group(2)!));
}
bool fits(Look l, Term t) { final (c, r) = minSize(l); return t.cols >= c && t.rows >= r; }

/// The look after [from] in [cycle] that fits [t], or null when no other look does.
Look? nextLook(String from, Term t) {
  final at = cycle.indexWhere((l) => l.id == from);
  for (var i = 1; i <= cycle.length; i++) {
    final l = cycle[(at + i) % cycle.length];
    if (l.id != from && fits(l, t)) return l;
  }
  return null;
}

/// [want] when the terminal is big enough for it, else the plain look with a one-line hint. `HH_LOOK_MIN=COLSxROWS` raises the minimum of any look but plain (test hook).
Look fitLook(Look want, Term t) {
  if (want.id == plain.id) return want;
  if (fits(want, t)) return want;
  final (c, r) = minSize(want);
  return PlainLook(hint: tier(['Too small for the ${want.name} look (needs ${c}x$r): showing the plain list', 'Too small for ${want.id} (${c}x$r): plain list', 'plain list (${want.id} needs ${c}x$r)'], t.inner));
}
