// The rows of the Alarms and Settings forms, built from `hh check --read` plus the free-text fields. Data only; saving goes through the shell (Engine.saveKey), which validates.
import 'home_model.dart';

enum RowKind { toggle, number, text, action, look, restore, info }

class FormRow {
  const FormRow(this.key, this.label, this.kind, this.value, this.hint, [this.edit = '']);
  /// The config key it writes (`schedule` is the launchd switch; `test` and `ui` open an action).
  final String key, label, value, hint;
  final RowKind kind;
  /// What an edit starts from (empty for a toggle or action).
  final String edit;
  bool get on => value == 'on';
}

String _g(double? v) => v == null ? '' : v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
String _onOff(bool b) => b ? 'on' : 'off';

/// Alarms: the schedule switch, how often, the three lines, who is told and when.
List<FormRow> alarmRows(Reading r) {
  final every = '${r.everyMin ?? 30}';
  return [
    FormRow('schedule', 'Checks', RowKind.toggle, _onOff(r.alarmsOn), r.alarmsOn ? 'a launchd job reads the machine' : 'nothing runs in the background'),
    FormRow('check_every_min', 'Check every', RowKind.number, '$every min', '5 to 1440 minutes', every),
    FormRow('min_free_gb', 'Disk floor', RowKind.number, '${_g(r.floorGb)} GiB', 'warns below this', _g(r.floorGb)),
    FormRow('hard_gb', 'Disk stop', RowKind.number, '${_g(r.stopGb)} GiB', 'critical, and builds are refused', _g(r.stopGb)),
    FormRow('mem_free_pct', 'Memory line', RowKind.number, '${r.memLinePct ?? 15} % free', 'warns below; critical at half', '${r.memLinePct ?? 15}'),
    FormRow('check_mem', 'Memory alarm', RowKind.toggle, _onOff(r.checkMem), 'tell me when memory is tight'),
    FormRow('max_load', 'CPU load', RowKind.number, _g(r.maxLoad), 'warns at this 5-minute load; critical at 2x', _g(r.maxLoad)),
    FormRow('check_cpu', 'CPU alarm', RowKind.toggle, _onOff(r.checkCpu), 'tell me when the machine is busy'),
    FormRow('notify', 'Notify', RowKind.toggle, _onOff(r.notify), 'show a notification'),
    FormRow('quiet_hours', 'Quiet hours', RowKind.text, r.quiet, 'off, or START-END like 22-7; warnings only', r.quiet),
    const FormRow('test', 'Test alert', RowKind.action, 'send now', 'shows how an alert looks'),
  ];
}

/// Settings: the look, and what to call you.
List<FormRow> settingsRows(Reading r, {required String look, String name = '', String role = '', List<String> ignored = const []}) => [
  FormRow('ui', 'Look', RowKind.look, look, 'enter opens the chooser'),
  FormRow('name', 'Name', RowKind.text, name.isEmpty ? 'not set' : name, '1 to 40 characters', name),
  FormRow('role', 'Role', RowKind.text, role.isEmpty ? 'not set' : role, 'what you do, 1 to 40 characters', role),
  if (ignored.isEmpty) const FormRow('ignored_apps', 'Ignored apps', RowKind.info, 'none', 'press i on the Memory or CPU screen to ignore one')
  else for (final n in ignored) FormRow('ignored_apps', 'Ignored', RowKind.restore, n, 'enter restores it', n),
];

/// Whether [c] may be typed into a row of [kind]. The shell validates the whole value on save.
bool typable(RowKind kind, String c) {
  if (c.length != 1 || c.codeUnitAt(0) < 32 || c.codeUnitAt(0) == 127) return false;
  if (kind == RowKind.number) return RegExp(r'[0-9.]').hasMatch(c);
  return c != '=';
}
