// Keys on the Home screen. Opening an area only changes which screen shows; nothing here closes, kills or signals anything.
import 'package:nocterm/nocterm.dart';
import 'home_model.dart';
import 'perf_model.dart';
import 'state.dart';


/// Opens [area]: Storage returns to the existing pick flow, Memory and CPU open their screen, Alarms and Settings open their form.
void openArea(AppState s, Area area, {void Function()? enterStorage}) {
  s.homeNote = '';
  switch (area) {
    case Area.storage: s.home = false; enterStorage?.call();
    case Area.memory: s.screen = Resource.memory;
    case Area.cpu: s.screen = Resource.cpu;
    case Area.alarms || Area.settings: s.form = area; s.formSel = 0;
  }
}

/// Handles a Home key; returns true when used. [rescan] re-reads the machine, [look] cycles looks (V saves), [quit] leaves.
bool handleHomeKey(AppState s, KeyboardEvent k, void Function(void Function()) redraw, {required void Function() rescan, required void Function(bool save) look, required void Function() quit, void Function()? enterStorage}) {
  final lk = k.logicalKey, n = Area.values.length;
  if (k.isControlPressed) return false;
  if (lk == LogicalKey.arrowDown || lk == LogicalKey.keyJ || lk == LogicalKey.arrowRight) { redraw(() { s.homeSel = (s.homeSel + 1) % n; s.homeNote = ''; }); return true; }
  if (lk == LogicalKey.arrowUp || lk == LogicalKey.keyK || lk == LogicalKey.arrowLeft) { redraw(() { s.homeSel = (s.homeSel + n - 1) % n; s.homeNote = ''; }); return true; }
  if (lk == LogicalKey.enter) { redraw(() => openArea(s, Area.values[s.homeSel], enterStorage: enterStorage)); return true; }
  const jump = {'s': Area.storage, 'm': Area.memory, 'c': Area.cpu, 'a': Area.alarms, 'g': Area.settings};
  final a = jump[(k.character ?? '').toLowerCase()];
  if (a != null) { redraw(() { s.homeSel = a.index; openArea(s, a, enterStorage: enterStorage); }); return true; }
  if (lk == LogicalKey.keyR) { rescan(); return true; }
  if (lk == LogicalKey.keyV) { look(k.character == 'V' || k.isShiftPressed); return true; }
  if (lk == LogicalKey.keyL) { redraw(() { s.picking = true; s.pickFirst = false; }); return true; }
  if (lk == LogicalKey.keyQ || lk == LogicalKey.escape) { quit(); return true; }
  return false;
}
