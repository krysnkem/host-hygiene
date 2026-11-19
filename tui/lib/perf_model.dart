// The running-apps model shared by the Memory and CPU screens. Data only: no drawing, and nothing here can close, kill or signal a process.
import 'dart:io';

/// The three things hh watches.
enum Resource { storage, memory, cpu }

class AppRow {
  AppRow(this.rank, this.name, this.procs, this.cpu, this.mb, this.kind, this.advice);
  final int rank, procs, mb;
  final double cpu;
  final String name, kind, advice;
  /// app | tool | system. System items are never ticked and never advised to be closed.
  bool get system => kind == 'system';
  bool get closable => !system && advice.isNotEmpty;
}

/// The config's ignored_apps text -> names (trimmed, no blanks, no repeats). The shell stores them comma-separated.
List<String> parseIgnored(String s) { final out = <String>[]; for (final n in s.split(',')) { final t = n.trim(); if (t.isNotEmpty && !out.contains(t)) out.add(t); } return out; }
String joinIgnored(Iterable<String> l) => l.join(',');

String mem(int mb) => mb >= 1024 ? '${(mb / 1024).toStringAsFixed(1)} GB' : '$mb MB';

/// `apps.sh --tsv` lines -> rows. Malformed lines are skipped.
List<AppRow> parseApps(String tsv) {
  final out = <AppRow>[];
  for (final l in tsv.split('\n')) {
    final f = l.split('\t');
    if (f.length < 6) continue;
    out.add(AppRow(int.tryParse(f[0]) ?? 0, f[1], int.tryParse(f[2]) ?? 1, double.tryParse(f[3]) ?? 0, int.tryParse(f[4]) ?? 0, f[5], f.length > 6 ? f[6] : ''));
  }
  return out;
}

Future<List<AppRow>> loadApps(String script) async {
  try {
    final r = await Process.run('${File(script).parent.path}/apps.sh', ['--tsv']);
    return parseApps(r.stdout as String);
  } catch (_) { return []; }
}

/// Memory ranks by RAM, CPU by CPU share, Storage has no apps. Ties keep the original order; system items sink below the rest.
List<AppRow> rankFor(Resource r, List<AppRow> rows) {
  final l = [for (final a in rows) a];
  int by(AppRow a, AppRow b) => r == Resource.cpu ? b.cpu.compareTo(a.cpu) : b.mb.compareTo(a.mb);
  final idx = {for (var i = 0; i < l.length; i++) l[i]: i};
  l.sort((a, b) { if (a.system != b.system) return a.system ? 1 : -1; final c = by(a, b); return c != 0 ? c : idx[a]!.compareTo(idx[b]!); });
  return l;
}

/// What quitting the ticked apps would free, in MB (memory) or cores' worth of percent (cpu). System items count for nothing.
int freedMb(Iterable<AppRow> ticked) => ticked.where((a) => !a.system).fold(0, (s, a) => s + a.mb);
double freedCpu(Iterable<AppRow> ticked) => ticked.where((a) => !a.system).fold(0.0, (s, a) => s + a.cpu);
