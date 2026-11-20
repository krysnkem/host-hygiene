// The Alarms and Settings screens: rows you move through, Enter edits or flips one, and a save writes the same config key `hh config set` writes.
// The shell validates, so the CLI and this screen cannot disagree. Nothing here closes, kills or signals a process.
import 'dart:async';
import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'engine.dart';
import 'form_model.dart';
import 'home_model.dart';
import 'layout.dart';
import 'look.dart';
import 'state.dart';
import 'ui.dart';

class FormView extends StatefulComponent {
  const FormView({super.key, required this.s, required this.onLook, required this.onClose});
  final AppState s;
  /// Open the look chooser (the form stays underneath and reloads afterwards).
  final void Function() onLook;
  /// Leave the form; [fresh] is the latest reading so Home shows what was just saved.
  final void Function(Reading? fresh) onClose;
  @override
  State<FormView> createState() => _FormViewState();
}

class _FormViewState extends State<FormView> {
  final eng = Engine();
  Reading? rd;
  List<String> ign = [];
  String name = '', role = '', note = '', text = '';
  bool bad = false, editing = false, busy = false;
  int top = 0;
  StreamSubscription<ProcessSignal>? winch;

  AppState get s => component.s;
  bool get alarms => s.form == Area.alarms;
  List<FormRow> get rows => alarms ? alarmRows(rd ?? Reading()) : settingsRows(rd ?? Reading(), look: lookFor(s.lookId).name, name: name, role: role, ignored: ign);

  @override
  void initState() {
    super.initState();
    try { winch = ProcessSignal.sigwinch.watch().listen((_) => setState(() {})); } catch (_) {}
    _load();
  }

  @override
  void dispose() { winch?.cancel(); super.dispose(); }

  Future<void> _load() async {
    final r = await eng.reading(), n = alarms ? '' : await eng.field('name'), o = alarms ? '' : await eng.field('role'), g = alarms ? <String>[] : await eng.ignored();
    if (mounted) setState(() { rd = r; name = n; role = o; ign = g; });
  }

  Future<void> _save(FormRow row, String v) async {
    if (busy) return;
    busy = true;
    final err = await eng.saveKey(row.key, v);
    await _load();
    busy = false;
    if (!mounted) return;
    setState(() { editing = false; bad = err != null; note = err ?? (row.key == 'schedule' ? (v == 'on' ? 'saved: alarms on' : 'saved: alarms off') : 'saved'); });
  }

  Future<void> _test() async {
    if (busy) return;
    busy = true; final r = await eng.testAlert(); busy = false;
    if (mounted) setState(() { bad = false; note = r.isEmpty ? 'sent' : r; });
  }

  Future<void> _restore(FormRow row) async {
    if (busy) return;
    busy = true;
    final err = await eng.setIgnored([for (final n in ign) if (n != row.edit) n]);
    await _load();
    busy = false;
    if (mounted) setState(() { bad = err != null; note = err ?? '${row.edit} will be advised and named in alarms again'; final n = rows.length; if (s.formSel >= n) s.formSel = n - 1; });
  }

  void _activate(FormRow row) {
    switch (row.kind) {
      case RowKind.restore: _restore(row);
      case RowKind.info: break;
      case RowKind.toggle: _save(row, row.on ? 'off' : 'on');
      case RowKind.action: _test();
      case RowKind.look: component.onLook();
      case RowKind.number || RowKind.text: setState(() { editing = true; text = row.edit; note = ''; bad = false; });
    }
  }

  bool _key(KeyboardEvent k) {
    final lk = k.logicalKey, c = k.character ?? '', rs = rows, n = rs.length;
    if (editing) {
      if (lk == LogicalKey.escape || (k.isControlPressed && lk == LogicalKey.keyC)) { setState(() { editing = false; note = ''; }); return true; }
      if (lk == LogicalKey.enter) { _save(rs[s.formSel.clamp(0, n - 1)], text.trim()); return true; }
      if (lk == LogicalKey.backspace) { if (text.isNotEmpty) setState(() { text = text.substring(0, text.length - 1); note = ''; }); return true; }
      if (!k.isControlPressed && text.length < 40 && typable(rs[s.formSel.clamp(0, n - 1)].kind, c)) { setState(() { text += c; note = ''; }); return true; }
      return true;
    }
    if (lk == LogicalKey.escape || lk == LogicalKey.keyQ || (k.isControlPressed && lk == LogicalKey.keyC)) { component.onClose(rd); return true; }
    if (k.isControlPressed || n == 0) return false;
    if (lk == LogicalKey.arrowDown || lk == LogicalKey.keyJ) { setState(() { s.formSel = (s.formSel + 1) % n; note = ''; }); return true; }
    if (lk == LogicalKey.arrowUp || lk == LogicalKey.keyK) { setState(() { s.formSel = (s.formSel + n - 1) % n; note = ''; }); return true; }
    if (lk == LogicalKey.enter || lk == LogicalKey.space) { _activate(rs[s.formSel.clamp(0, n - 1)]); return true; }
    if (alarms && lk == LogicalKey.keyT) { _test(); return true; }
    return false;
  }

  @override
  Component build(BuildContext context) {
    final t = Term(), g = Gl.i, w = t.inner, rs = rows, sel = s.formSel.clamp(0, rs.length - 1), win = (t.rows - 4).clamp(3, 20);
    if (sel >= top + win) top = sel - win + 1;
    if (sel < top) top = sel;
    final valW = (w - 17).clamp(8, 30), hintW = (w - 19 - valW).clamp(0, 60);
    return Focusable(focused: true, onKeyEvent: _key, child: Padding(padding: EdgeInsets.symmetric(horizontal: 1), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      line(alarms ? 'Alarms' : 'Settings', w, color: Colors.white, bold: true),
      for (var i = top; i < rs.length && i < top + win; i++) _row(rs[i], i == sel, valW, hintW, w, g),
      if (note.isNotEmpty) line(note, w, color: bad ? Colors.yellow : Colors.green),
      keys(editing ? ['enter save ${g.dot} esc cancel ${g.dot} writes the same config as hh config set', 'enter save ${g.dot} esc cancel', 'enter esc'] : ['${g.ud} move ${g.dot} enter edit or flip${alarms ? ' ${g.dot} t test alert' : ''} ${g.dot} esc back', '${g.ud} enter ${g.dot} esc', 'enter esc'], w),
    ])));
  }

  Component _row(FormRow r, bool on, int valW, int hintW, int w, Gl g) {
    final v = on && editing ? '$text${g.cursor}' : r.value, h = hintW >= 12 ? fit(r.hint, hintW) : '';
    return Text(fit('${on ? g.arrow : ' '} ${r.label.padRight(13)} ${fit(v, valW).padRight(valW)} $h', w), softWrap: false,
        style: TextStyle(color: on ? Colors.black : (r.kind == RowKind.toggle && !r.on ? Colors.brightBlack : Colors.white), backgroundColor: on ? Colors.magenta : null, fontWeight: on ? FontWeight.bold : null));
  }
}
