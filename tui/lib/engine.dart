// Bridge to the host-hygiene shell scripts. The scripts are the ONLY thing that can delete.
import 'dart:convert';
import 'dart:io';
import 'home_model.dart';
import 'perf_model.dart';

class Item {
  Item(this.kb, this.cls, this.cost, this.id, this.path, this.cmd, this.supported, this.note, this.upper);
  final int kb; final String cls, id, path, cmd, note; final int cost; final bool supported, upper;
  bool get safe => cls == 'safe-regenerable';
  bool on = false;
  String get name => path.replaceFirst(Platform.environment['HOME'] ?? '', '~');
}

class Profile {
  Profile(this.kind, this.tools, this.projects, [this.kinds = const []]);
  final String kind; final List<String> tools; final List<List<String>> projects; // [active, path, kinds]
  final List<DevKind> kinds; // engine "kind" rows: one per detected developer type
}

class DevKind {
  DevKind(this.id, this.active, this.all, this.tool);
  final String id; final int active, all; final bool tool;
}

String size(int kb) {
  if (kb >= 1048576) return '${(kb / 1048576).toStringAsFixed(1)}G';
  if (kb >= 1024) return '${(kb / 1024).toStringAsFixed(kb >= 10240 ? 0 : 1)}M';
  return '${kb}K';
}

/// "12M" / "1.5G" as printed by the engine's hr() -> KB. Unknown text counts as 0.
int parseSize(String s) {
  final m = RegExp(r'^([\d.]+)([BKMGT])$').firstMatch(s); if (m == null) return 0;
  final n = double.tryParse(m.group(1)!) ?? 0;
  return (n * const {'B': 1 / 1024, 'K': 1, 'M': 1024, 'G': 1048576, 'T': 1073741824}[m.group(2)]!).round();
}

/// One apply line for a person: "REFUSED  ~/x  (why)" -> "REFUSED ~/x: why". Long tool paths inside ERROR lines are trimmed.
String readable(String r) {
  final m = RegExp(r'^(\S+)\s+(.*?)\s*\((.*)\)\s*$').firstMatch(r);
  return m == null ? r : '${m.group(1)} ${m.group(2)}: ${m.group(3)}';
}

/// One plain sentence for a removal error, or empty when the raw text is all there is.
String errorHint(String r) {
  if (r.contains('Directory not empty')) return 'Something kept adding files while it was removed, often the app that owns the folder or its background helper. Quit that app and try this one again.';
  if (r.contains('Operation not permitted')) return 'macOS blocked it. Allow your terminal under System Settings > Privacy & Security > App Management (or Full Disk Access), then try again.';
  if (r.contains('Permission denied')) return 'You do not have permission to remove it.';
  return '';
}

class Engine {
  Engine() : script = Platform.environment['HH_SCRIPT'] ?? '${File(Platform.resolvedExecutable).parent.parent.path}/scripts/host-hygiene.sh';
  final String script;
  String get cfg => Platform.environment['HH_CONFIG'] ?? '${Platform.environment['HOME']}/.config/host-hygiene/config';
  /// True once the thresholds were asked: a file holding only `ui=` does not count.
  bool get configExists { try { return File(cfg).readAsLinesSync().any((l) => RegExp(r'^\s*min_free_gb\s*=').hasMatch(l)); } catch (_) { return false; } }

  /// The `ui=` value in the config file, or null; HH_LOOK counts as chosen too. Used only to ask the first-run look question once.
  String? get uiInFile {
    final e = Platform.environment['HH_LOOK'] ?? '';
    if (e.isNotEmpty) return e;
    try { for (final l in File(cfg).readAsLinesSync().reversed) { final m = RegExp(r'^\s*ui\s*=\s*([a-z]+)\s*$').firstMatch(l); if (m != null) return m.group(1); } } catch (_) {}
    return null;
  }

  Future<List<String>> _run(List<String> a) async {
    final r = await Process.run(script, a, environment: {'HH_NO_PROMPT': '1'});
    return const LineSplitter().convert(r.stdout as String);
  }

  Future<Map<String, String>> guard() async {
    final m = <String, String>{};
    for (final l in await _run(['guard', '--kv'])) { final i = l.indexOf('='); if (i > 0) m[l.substring(0, i)] = l.substring(i + 1); }
    return m;
  }

  Future<Profile> profile() async {
    String kind = 'developer'; final tools = <String>[]; final proj = <List<String>>[]; final kinds = <DevKind>[];
    for (final l in await _run(['profile', '--tsv'])) {
      final f = l.split('\t');
      if (f[0] == 'meta' && f.length > 2) kind = f[2];
      if (f[0] == 'tc') tools.add(f[1]);
      if (f[0] == 'proj' && f.length > 3) proj.add([f[1], f[2], f[3]]);
      if (f[0] == 'kind' && f.length > 4) kinds.add(DevKind(f[1], int.tryParse(f[2]) ?? 0, int.tryParse(f[3]) ?? 0, f[4] == 'y'));
    }
    return Profile(kind, tools, proj, kinds);
  }

  Future<List<Item>> plan(int minMb) async {
    final out = <Item>[];
    for (final l in await _run(['plan', '--tsv', '--min-mb', '$minMb'])) {
      if (l.startsWith('#') || l.trim().isEmpty) continue;
      final f = l.split('\t'); if (f.length < 9) continue;
      out.add(Item(int.tryParse(f[1]) ?? 0, f[2], int.tryParse(f[3]) ?? 2, f[4], f[5], f[6], f[7] == 'y', f[8], f.length > 9 && f[9] == '<='));
    }
    return out;
  }

  /// `check --read`: the three readings and the alarm settings, whatever the alarm switches say. Unreadable output leaves fields unknown.
  Future<Reading> reading() async => parseReading((await _run(['check', '--read'])).join('\n'));

  /// The look id the shell resolved: HH_LOOK, then `ui=` in the config, else guided. The shell holds the allowed list.
  Future<String> ui() async {
    final l = await _run(['config', 'get', 'ui']);
    return l.isEmpty ? 'guided' : l.first.trim();
  }

  /// Saves the default look through the shell, the same path as `config set ui <id>`.
  Future<bool> setUi(String id) async {
    final r = await Process.run(script, ['config', 'set', 'ui', id], environment: {'HH_NO_PROMPT': '1'});
    return r.exitCode == 0;
  }

  /// Saves a free-text field (`name`, `role`) through the shell: `config set name <text>`.
  Future<bool> setField(String key, String value) async {
    final r = await Process.run(script, ['config', 'set', key, value], environment: {'HH_NO_PROMPT': '1'});
    return r.exitCode == 0;
  }

  /// Saves one Alarms or Settings value the way the CLI does: `config set`, or `schedule on|off` for the `schedule` switch. Returns the CLI's own message when it refuses, else null.
  Future<String?> saveKey(String key, String v) async {
    Future<String?> run(List<String> a) async {
      final r = await Process.run(script, a, environment: {'HH_NO_PROMPT': '1'});
      return r.exitCode == 0 ? null : '${r.stderr}'.trim().split('\n').first;
    }
    if (key == 'schedule') return run(['schedule', v == 'on' ? 'on' : 'off']);
    final err = await run(['config', 'set', key, v]);
    if (err == null && key == 'check_every_min' && (await reading()).alarmsOn) return run(['schedule', 'on', '--every', v]);
    return err;
  }

  /// The apps the user chose to never hear about (`ignored_apps` in the config).
  Future<List<String>> ignored() async => parseIgnored(await field('ignored_apps'));
  Future<String?> setIgnored(List<String> l) => saveKey('ignored_apps', joinIgnored(l));

  /// `hh snooze`: keeps one alarm quiet for [d] (1h, 4h, 24h, tomorrow, off). Returns the line saying what happened.
  Future<String> snooze(Resource r, String d) async {
    final p = await Process.run(script, ['snooze', r == Resource.cpu ? 'cpu' : r == Resource.memory ? 'memory' : 'disk', d], environment: {'HH_NO_PROMPT': '1'});
    return '${p.exitCode == 0 ? p.stdout : p.stderr}'.trim();
  }

  /// Sends the sample alert (`check --test`); returns the line saying how it went.
  Future<String> testAlert() async => (await _run(['check', '--test'])).join(' ').trim();

  /// `config get <key>`: empty when unset.
  Future<String> field(String key) async => (await _run(['config', 'get', key])).join(' ').trim();

  Future<void> setLimits(int soft, int hard, int load) async {
    await _run(['config', 'set', 'min_free_gb', '$soft']); await _run(['config', 'set', 'hard_gb', '$hard']); await _run(['config', 'set', 'max_load', '$load']);
  }

  /// Streams apply output lines. Uses --yes because the user already confirmed on the Confirm step.
  Stream<String> apply(List<Item> chosen) async* {
    final args = ['apply', '--run', '--yes', '--keep-going', if (chosen.any((i) => !i.safe)) '--ask-first-ok', for (final i in chosen) ...['--target', i.path]];
    final p = await Process.start(script, args, environment: {'HH_NO_PROMPT': '1'});
    yield* p.stdout.transform(utf8.decoder).transform(const LineSplitter());
  }
}
