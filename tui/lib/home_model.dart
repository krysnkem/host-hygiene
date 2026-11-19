// The Home screen's rows: one per resource plus Alarms and Settings, built from `hh check --read`. Data only.
import 'perf_model.dart';

enum Level { ok, warn, crit, unknown }

Level levelOf(String s) => const {'ok': Level.ok, 'warn': Level.warn, 'crit': Level.crit}[s] ?? Level.unknown;

class Reading {
  Reading({this.diskLevel = Level.unknown, this.freeGb, this.floorGb, this.stopGb, this.memLevel = Level.unknown, this.memFreePct, this.memLinePct, this.cpuLevel = Level.unknown, this.load, this.maxLoad, this.cores,
      this.snoozes = const {}, this.alarmsOn = false, this.everyMin, this.notify = true, this.quiet = 'off', this.checkMem = true, this.checkCpu = true});
  final Level diskLevel, memLevel, cpuLevel;
  final double? freeGb, floorGb, stopGb, load, maxLoad;
  final int? memFreePct, memLinePct, cores, everyMin;
  final bool alarmsOn, notify, checkMem, checkCpu;
  final String quiet;
  /// Alarm snoozes still running: disk | mem | cpu -> epoch seconds they end.
  final Map<String, int> snoozes;
  /// When this resource's alarm is snoozed until, or null.
  DateTime? snoozedUntil(Resource r) { final e = snoozes[r == Resource.storage ? 'disk' : r == Resource.memory ? 'mem' : 'cpu']; return e == null ? null : DateTime.fromMillisecondsSinceEpoch(e * 1000); }
  Level levelFor(Resource r) => r == Resource.storage ? diskLevel : r == Resource.memory ? memLevel : cpuLevel;
}

/// `check --read` output -> a [Reading]. Missing or malformed lines leave their fields unknown.
Reading parseReading(String tsv) {
  Level dl = Level.unknown, ml = Level.unknown, cl = Level.unknown;
  double? free, floor, stop, load, maxLoad; int? memFree, memLine, cores, every;
  final snz = <String, int>{};
  var on = false, notify = true, cm = true, cc = true, quiet = 'off';
  for (final l in tsv.split('\n')) {
    final f = l.split('\t');
    switch (f[0]) {
      case 'disk' when f.length >= 5: dl = levelOf(f[1]); free = double.tryParse(f[2]); floor = double.tryParse(f[3]); stop = double.tryParse(f[4]);
      case 'memory' when f.length >= 4: ml = levelOf(f[1]); memFree = int.tryParse(f[2]); memLine = int.tryParse(f[3]);
      case 'cpu' when f.length >= 5: cl = levelOf(f[1]); load = double.tryParse(f[2]); maxLoad = double.tryParse(f[3]); cores = int.tryParse(f[4]);
      case 'snooze' when f.length >= 3: final e = int.tryParse(f[2]); if (e != null) snz[f[1]] = e;
      case 'alarms' when f.length >= 8: on = f[1] == 'on'; every = int.tryParse(f[2]); notify = f[3] != 'off'; quiet = f[4].isEmpty ? 'off' : f[4]; cm = f[5] != 'off'; cc = f[6] != 'off';
    }
  }
  return Reading(diskLevel: dl, freeGb: free, floorGb: floor, stopGb: stop, memLevel: ml, memFreePct: memFree, memLinePct: memLine, cpuLevel: cl, load: load, maxLoad: maxLoad, cores: cores,
      snoozes: snz, alarmsOn: on, everyMin: every, notify: notify, quiet: quiet, checkMem: cm, checkCpu: cc);
}

enum Area { storage, memory, cpu, alarms, settings }

class HomeRow {
  const HomeRow(this.area, this.key, this.title, this.status, this.level, [this.brief = const []]);
  final Area area;
  /// Short lines for a small panel (the Cockpit's Home); empty means split [status] at its commas.
  final List<String> brief;
  final String key, title, status;
  final Level level;
  /// The word shown at the end of a resource row; empty for Alarms and Settings.
  String get word => const {Level.ok: 'ok', Level.warn: 'LOW', Level.crit: 'CRITICAL'}[level] ?? '';
}

String _g(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// The five Home rows, in order. [look] and [ignored] feed the Settings line.
List<HomeRow> homeRows(Reading r, {String look = 'guided', int ignored = 0}) {
  final cpuWord = r.cpuLevel == Level.ok ? 'below' : 'over';
  return [
    HomeRow(Area.storage, 's', 'Storage', r.freeGb == null ? 'not read yet' : '${_g(r.freeGb!)} GiB free, ${r.diskLevel == Level.ok ? 'above' : 'below'} the ${_g(r.floorGb ?? 0)} GiB floor', r.diskLevel, r.freeGb == null ? const [] : ['${_g(r.freeGb!)} GiB free', 'floor ${_g(r.floorGb ?? 0)} GiB']),
    HomeRow(Area.memory, 'm', 'Memory', r.memFreePct == null ? 'not read yet' : '${r.memFreePct}% free, ${r.memLevel == Level.ok ? 'above' : 'below'} the ${r.memLinePct ?? 15}% line', r.memLevel, r.memFreePct == null ? const [] : ['${r.memFreePct}% free', 'line ${r.memLinePct ?? 15}%']),
    HomeRow(Area.cpu, 'c', 'CPU', r.load == null ? 'not read yet' : 'load ${_g(r.load!)}, $cpuWord the max ${_g(r.maxLoad ?? 0)}', r.cpuLevel, r.load == null ? const [] : ['load ${_g(r.load!)}', 'max ${_g(r.maxLoad ?? 0)}${r.cores == null ? '' : ', ${r.cores} cores'}']),
    HomeRow(Area.alarms, 'a', 'Alarms', r.alarmsOn ? 'on, every ${r.everyMin ?? 30} min${r.quiet == 'off' ? '' : ', quiet ${r.quiet}'}' : 'off', Level.unknown),
    HomeRow(Area.settings, 'g', 'Settings', 'look $look${ignored > 0 ? ', $ignored app${ignored == 1 ? '' : 's'} ignored' : ''}', Level.unknown),
  ];
}
