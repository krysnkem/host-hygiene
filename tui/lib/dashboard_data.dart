// Live numbers for the dashboard look. One cheap call per poll (`uptime; df -k /`); the process lists come from the existing scripts/perf.sh, every third poll only.
import 'dart:io';

class Proc {
  const Proc(this.name, this.cpu, this.mb);
  final String name;
  final double cpu;
  final int mb;
}

/// The soft floor, hard stop and load limit, as the guard reported them.
class Lim {
  Lim(Map<String, String> g)
      : soft = double.tryParse(g['min_free_gb'] ?? '') ?? 15,
        hard = double.tryParse(g['hard_gb'] ?? '') ?? 5,
        load = double.tryParse(g['max_load'] ?? '') ?? 8;
  final double soft, hard, load;
}

class DashData {
  double l1 = 0, l5 = 0, l15 = 0;
  int totalKb = 0, availKb = 0;
  bool loaded = false, procsLoaded = false;
  List<Proc> byCpu = const [], byMem = const [];
  final hist = <double>[];
  double get freeGb => availKb / 1048576;
  double get totalGb => totalKb / 1048576;
  /// What is drawn from this data; a poll that leaves it unchanged costs no redraw.
  String get shown => '${l1.toStringAsFixed(2)} ${l5.toStringAsFixed(2)} ${l15.toStringAsFixed(2)} ${freeGb.toStringAsFixed(1)} ${totalGb.round()} '
      '${byCpu.map((p) => '${p.name}${p.cpu}${p.mb}').join()}|${byMem.map((p) => '${p.name}${p.cpu}${p.mb}').join()}';
}

class DashPoller {
  DashPoller(String script) : perf = '${File(script).parent.path}/perf.sh';
  final String perf;
  final d = DashData();
  int _n = 0;
  static const keep = 60;
  static final _up = RegExp(r'load averages?:\s*([\d.]+)[,\s]+([\d.]+)[,\s]+([\d.]+)');
  static final _cpu = RegExp(r'^\s+cpu\s+([\d.]+)%\s+(\d+)M\s+(.+?)\s*$');
  static final _mem = RegExp(r'^\s+mem\s+(\d+)M\s+([\d.]+)%\s+(.+?)\s*$');

  /// Show the guard's numbers until the first poll lands.
  void seed(Map<String, String> g) {
    final l = double.tryParse(g['load'] ?? ''), f = double.tryParse(g['free_gb'] ?? '');
    if (l != null && !d.loaded) { d.l1 = l; d.l5 = l; d.l15 = l; }
    if (f != null && !d.loaded) d.availKb = (f * 1048576).round();
  }

  /// One poll. True when something on screen would look different.
  Future<bool> poll() async {
    final before = d.shown, withPerf = _n++ % 3 == 0;
    final fast = Process.run('/bin/sh', ['-c', 'uptime; df -k /']).timeout(const Duration(seconds: 8));
    final slow = withPerf ? Process.run('/bin/bash', [perf, 'report']).timeout(const Duration(seconds: 20)) : null;
    try {
      final out = (await fast).stdout as String, m = _up.firstMatch(out);
      if (m != null) { d.l1 = double.parse(m.group(1)!); d.l5 = double.parse(m.group(2)!); d.l15 = double.parse(m.group(3)!); d.loaded = true; }
      final ls = out.split('\n'), i = ls.indexWhere((l) => l.startsWith('Filesystem'));
      if (i >= 0 && i + 1 < ls.length) {
        final f = ls[i + 1].trim().split(RegExp(r'\s+'));
        if (f.length > 3) { d.totalKb = int.tryParse(f[1]) ?? d.totalKb; d.availKb = int.tryParse(f[3]) ?? d.availKb; }
      }
      d.hist.add(d.l1);
      if (d.hist.length > keep) d.hist.removeAt(0);
    } catch (_) {}
    if (slow != null) {
      try { _parsePerf((await slow).stdout as String); } catch (_) {}
    }
    return d.shown != before;
  }

  void _parsePerf(String out) {
    final c = <Proc>[], m = <Proc>[];
    for (final l in out.split('\n')) {
      final a = _cpu.firstMatch(l), b = _mem.firstMatch(l);
      if (a != null) c.add(Proc(a.group(3)!, double.parse(a.group(1)!), int.parse(a.group(2)!)));
      if (b != null) m.add(Proc(b.group(3)!, double.parse(b.group(2)!), int.parse(b.group(1)!)));
    }
    if (c.isNotEmpty || m.isNotEmpty) { d.byCpu = c; d.byMem = m; d.procsLoaded = true; }
  }
}
