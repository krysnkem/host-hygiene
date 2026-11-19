// Run: dart run tests/home_model.dart   (exit 1 on any failure)
import 'dart:io';
import 'package:hh_tui/advice_text.dart';
import 'package:hh_tui/form_model.dart';
import 'package:hh_tui/home_model.dart';
import 'package:hh_tui/perf_model.dart';
import 'package:hh_tui/resource_rows.dart';

var bad = 0, n = 0;
void eq(Object? a, Object? b, String what) { n++; if ('$a' != '$b') { bad++; print('FAIL $what: got $a want $b'); } }
AppRow app(String name, int mb, double cpu, String kind, {String adv = 'x'}) => AppRow(0, name, 1, cpu, mb, kind, adv);

void main() {
  // readings
  final r = parseReading('disk\twarn\t11.6\t15\t5\nmemory\tok\t59\t15\ncpu\tcrit\t17.5\t8\t10\nalarms\ton\t30\ton\t22-7\toff\ton\t15\n');
  eq(r.diskLevel, Level.warn, 'disk level'); eq(r.freeGb, 11.6, 'free'); eq(r.floorGb, 15.0, 'floor'); eq(r.stopGb, 5.0, 'stop');
  eq(r.memLevel, Level.ok, 'mem level'); eq(r.memFreePct, 59, 'mem free'); eq(r.cpuLevel, Level.crit, 'cpu level'); eq(r.cores, 10, 'cores');
  eq(r.alarmsOn, true, 'alarms on'); eq(r.everyMin, 30, 'every'); eq(r.quiet, '22-7', 'quiet'); eq(r.checkMem, false, 'check_mem off'); eq(r.checkCpu, true, 'check_cpu on');
  eq(r.levelFor(Resource.storage), Level.warn, 'levelFor storage'); eq(r.levelFor(Resource.memory), Level.ok, 'levelFor memory'); eq(r.levelFor(Resource.cpu), Level.crit, 'levelFor cpu');
  final e = parseReading('');
  eq(e.diskLevel, Level.unknown, 'empty disk'); eq(e.freeGb, null, 'empty free'); eq(e.alarmsOn, false, 'empty alarms');
  eq(parseReading('disk\tbogus\tx\ty\tz\nmemory\tok').memLevel, Level.unknown, 'short memory line ignored');
  eq(parseReading('alarms\toff\t\toff\toff\ton\ton\t15').quiet, 'off', 'quiet off'); eq(parseReading('alarms\toff\t\toff\toff\ton\ton\t15').notify, false, 'notify off');
  // home rows
  final rows = homeRows(r, look: 'console', ignored: 2);
  eq(rows.map((x) => x.area).toList(), Area.values, 'row order'); eq(rows.map((x) => x.key).join(), 'smcag', 'keys');
  eq(rows[0].status, '11.6 GiB free, below the 15 GiB floor', 'storage status'); eq(rows[0].word, 'LOW', 'storage word');
  eq(rows[1].status, '59% free, above the 15% line', 'memory status'); eq(rows[1].word, 'ok', 'memory word');
  eq(rows[2].status, 'load 17.5, over the max 8', 'cpu status'); eq(rows[2].word, 'CRITICAL', 'cpu word');
  eq(rows[3].status, 'on, every 30 min, quiet 22-7', 'alarms status'); eq(rows[4].status, 'look console, 2 apps ignored', 'settings status'); eq(rows[3].word, '', 'alarms has no word');
  eq(homeRows(e)[0].status, 'not read yet', 'unread storage'); eq(homeRows(e)[3].status, 'off', 'alarms off'); eq(homeRows(e, ignored: 1)[4].status, 'look guided, 1 app ignored', 'one ignored');
  // apps
  final rs = parseApps('1\tDocker\t9\t12\t4200\tapp\tquit it\n2\tqemu\t2\t170\t2000\ttool\tstop it\n3\tWindowServer\t1\t30\t900\tsystem\tnote\nbad line\n4\tChrome\t30\t8\t2600\tapp\t\n');
  eq(rs.length, 4, 'parseApps skips bad'); eq(rs[3].closable, false, 'no advice is not closable'); eq(rs[2].closable, false, 'system is not closable');
  eq(rankFor(Resource.memory, rs).map((a) => a.name).toList(), ['Docker', 'Chrome', 'qemu', 'WindowServer'], 'memory rank, system last');
  eq(rankFor(Resource.cpu, rs).map((a) => a.name).toList(), ['qemu', 'Docker', 'Chrome', 'WindowServer'], 'cpu rank, system last');
  eq(freedMb([rs[0], rs[2]]), 4200, 'system frees nothing'); eq(freedCpu([rs[0], rs[1]]), 182.0, 'cpu freed');
  // advice words
  eq(directions(app('A', 1, 1, 'app')).first.contains('Cmd-Q'), true, 'app: Cmd-Q'); eq(directions(app('A', 1, 1, 'app')).last.contains('Option-Cmd-Esc'), true, 'app: force quit');
  eq(directions(app('q', 1, 1, 'tool')).first.contains('Ctrl-C'), true, 'tool: Ctrl-C');
  final sys = directions(app('W', 1, 1, 'system', adv: 'close windows'));
  eq(sys.any((l) => RegExp(r'Cmd-Q|Quit|Force').hasMatch(l)), false, 'system: never a quit instruction'); eq(directions(app('W', 1, 1, 'system', adv: '')).first.contains('macOS'), true, 'system without advice');
  eq(summary(Resource.memory, [rs[0], rs[2]]), 'Quitting Docker would free about 4.1 GB. Save your work first.', 'summary memory'); eq(summary(Resource.cpu, [rs[1]]), 'Quitting qemu would free about 170% of a core. Save your work first.', 'summary cpu');
  eq(summary(Resource.memory, [rs[2]]), 'Nothing ticked.', 'summary of system only');
  // Memory and CPU screen text
  eq(headerText(Resource.memory, r), 'Memory: 59% free, your line is 15% (ok)', 'memory header'); eq(headerText(Resource.cpu, r), 'CPU: load 17.5 on 10 cores, your max is 8.0 (CRITICAL)', 'cpu header');
  eq(headerText(Resource.memory, null), 'Memory: reading...', 'header while loading'); eq(headerText(Resource.cpu, e), 'CPU: could not read the load just now', 'cpu header unread'); eq(headerText(Resource.memory, e), 'Memory: could not read it just now', 'memory header unread');
  eq(rowText(rs[0], true, 12, 0), '[x]  1  Docker          9   4.1 GB   12%  app', 'row ticked'); eq(rowText(rs[2], true, 12, 2).startsWith('    '), true, 'a system row has no tick box');
  eq(rowText(app('A very long application name', 1, 1, 'app'), false, 10, 0).contains('A very lo…'), true, 'long name cut');
  eq(tallyText(Resource.memory, []).contains('never closes anything'), true, 'tally hint says hh never closes'); eq(tallyText(Resource.memory, [rs[0]]), 'Ticked 1: closing them would free about 4.1 GB.', 'tally memory');
  eq(tallyText(Resource.cpu, [rs[1]]), 'Ticked 1: closing them would free about 170% of a core.', 'tally cpu'); eq(tallyText(Resource.memory, [rs[2]]).startsWith('Tick the apps'), true, 'system row ticked counts for nothing');
  eq(directionsText(null), '', 'no row, no directions'); eq(directionsText(rs[0]).startsWith('Docker: Save your work'), true, 'directions name the app');
  // forms
  final ar = alarmRows(r);
  eq(ar.map((x) => x.key).join(','), 'schedule,check_every_min,min_free_gb,hard_gb,mem_free_pct,check_mem,max_load,check_cpu,notify,quiet_hours,test', 'alarm row keys are config keys');
  eq(ar[0].value, 'on', 'schedule on'); eq(ar[1].value, '30 min', 'every'); eq(ar[1].edit, '30', 'edit starts from the bare number'); eq(ar[2].value, '15 GiB', 'floor');
  eq(ar[5].value, 'off', 'memory alarm off'); eq(ar[9].value, '22-7', 'quiet'); eq(ar[10].kind, RowKind.action, 'test is an action');
  eq(alarmRows(e)[0].value, 'off', 'no reading: alarms off'); eq(alarmRows(e)[1].value, '30 min', 'no reading: default every');
  final sr = settingsRows(r, look: 'Console', name: 'Sam');
  eq(sr.map((x) => x.key).join(','), 'ui,name,role,ignored_apps', 'settings keys'); eq(sr[1].value, 'Sam', 'name'); eq(sr[2].value, 'not set', 'role unset'); eq(sr[2].edit, '', 'unset edits from empty');
  eq(typable(RowKind.number, '7') && typable(RowKind.number, '.'), true, 'digits typable'); eq(typable(RowKind.number, 'x'), false, 'letters not in a number');
  eq(typable(RowKind.text, 'a') && typable(RowKind.text, '-'), true, 'text typable'); eq(typable(RowKind.text, '='), false, '= never typable'); eq(typable(RowKind.text, '\t'), false, 'control not typable');
  // ignore and snooze
  eq(parseIgnored(' Docker , Google Chrome,,Docker ').join('|'), 'Docker|Google Chrome', 'ignored list trims and dedupes'); eq(parseIgnored('').length, 0, 'empty list'); eq(joinIgnored(['A', 'B']), 'A,B', 'joined with commas');
  final ir = settingsRows(r, look: 'Console', ignored: ['Docker', 'Xcode']);
  eq(ir.where((x) => x.kind == RowKind.restore).map((x) => x.edit).join(','), 'Docker,Xcode', 'one restore row per ignored app'); eq(sr.last.kind, RowKind.info, 'none ignored: an info row');
  final sn = parseReading('disk\tok\t50\t15\t5\nsnooze\tmem\t2000000000\nsnooze\tcpu\t5\n');
  eq(sn.snoozedUntil(Resource.memory) != null, true, 'memory snooze parsed'); eq(sn.snoozedUntil(Resource.storage), null, 'no disk snooze');
  final now = DateTime.fromMillisecondsSinceEpoch(1000 * 1000000);
  eq(snoozeText(Resource.cpu, parseReading('snooze\tcpu\t${1000000 + 3600}\n'), now: now).startsWith('Alarm snoozed until '), true, 'snooze text'); eq(snoozeText(Resource.cpu, parseReading('snooze\tcpu\t${1000000 - 5}\n'), now: now), '', 'an ended snooze says nothing'); eq(snoozeText(Resource.memory, e), '', 'no reading, no snooze text');
  // no process control in the new files
  for (final f in ['lib/perf_model.dart', 'lib/advice_text.dart', 'lib/home_model.dart', 'lib/resource_rows.dart', 'lib/resource_view.dart', 'lib/form_model.dart', 'lib/form_view.dart']) {
    final src = File(f).readAsStringSync();
    eq(RegExp(r'Process\.kill|killPid|Signal\.sig(term|kill|int)|pkill|killall|Process\.start|pbcopy|Activity Monitor\b.*open', caseSensitive: false).hasMatch(src.split('\n').where((l) => !l.trimLeft().startsWith('//')).join('\n')), false, 'no process control in $f');
  }
  print('home_model: $n checks, ${n - bad} passed, $bad failed'); exit(bad == 0 ? 0 : 1);
}
