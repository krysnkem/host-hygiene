// `hh focus` (opened by the low-disk notification): start on Pick with just enough safe items ticked to get back above the floor.
// Only safe-regenerable items are ever ticked here; ask-first items stay untouched for the user to judge.
import 'engine.dart';

/// Ticks the largest supported safe items until their sum covers the gap to the floor, and returns what Hy says about it.
List<String> focusTick(List<Item> items, Map<String, String> g) {
  final free = double.tryParse(g['free_gb'] ?? ''), floor = double.tryParse(g['min_free_gb'] ?? ''), hard = double.tryParse(g['hard_gb'] ?? '');
  if (free == null || floor == null) return ['I could not read the free space just now, so nothing is ticked. Pick what you want to clear.'];
  final head = free < (hard ?? 0) ? 'Disk is critically low: ${g['free_gb']} GiB free, below your hard stop of ${g['hard_gb']} GiB.' : 'Disk is at ${g['free_gb']} GiB free; your floor is ${g['min_free_gb']} GiB.';
  if (free >= floor) return ['$head That is above the floor, so nothing is ticked. Pick anything you want to clear.'];
  final needKb = ((floor - free) * 1048576).ceil(), safe = items.where((i) => i.safe && i.supported).toList()..sort((a, b) => b.kb.compareTo(a.kb));
  var sum = 0, n = 0;
  for (final i in safe) { if (sum >= needKb) break; i.on = true; sum += i.kb; n++; }
  final need = size(needKb), got = size(sum);
  if (n == 0) return ['$head I need about $need to get back above it, but I found no safe items to clear. Look at the ask-first ones, carefully.'];
  if (sum >= needKb) return ['$head To get back above it I need about $need.', 'I ticked the $n largest safe item${n == 1 ? '' : 's'} ($got). Review them, then continue.'];
  return ['$head I need about $need.', 'The safe items give only $got, so I ticked all $n and you are still ${size(needKb - sum)} short. The ask-first items could cover it; I left those for you to judge.'];
}
