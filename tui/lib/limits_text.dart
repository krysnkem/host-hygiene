// The first-run limits question in plain words: what each limit protects, and what the machine reads right now.
// One source for every look. Memory has no limit to set, and the text says so rather than implying one.
import 'layout.dart';

/// Three lines (disk, CPU, memory), each in the longest wording that fits [w] columns. Values come from `guard --kv`.
List<String> limitsLines(Map<String, String> g, int w) {
  final free = g['free_gb'] ?? '?', load = g['load'] ?? '?';
  final soft = g['min_free_gb'] ?? '15', hard = g['hard_gb'] ?? '5', maxl = g['max_load'] ?? '8';
  return [
    tier(['Disk    $free GiB free now. I warn you below $soft GiB and refuse builds below $hard GiB.', 'Disk: $free GiB free; warn below $soft, stop below $hard', 'Disk: $free free; warn <$soft, stop <$hard', 'Disk $free free, $soft/$hard'], w),
    tier(['CPU     load $load now. At $maxl or more the machine is too busy for reliable timings.', 'CPU: load $load; busy at $maxl or more', 'CPU: load $load; busy at $maxl+', 'CPU load $load, max $maxl'], w),
    tier(['Memory  I show what is using it, but there is no limit to set.', 'Memory: shown only, no limit', 'Memory: no limit'], w),
  ];
}
