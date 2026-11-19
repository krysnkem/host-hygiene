// What to tell a person about one running app. Words only: hh never closes, kills or signals anything, and never opens Activity Monitor or touches the clipboard.
import 'perf_model.dart';

/// Directions for [a], as short lines, chosen by its kind. A system item never gets a quit instruction.
List<String> directions(AppRow a) {
  switch (a.kind) {
    case 'app':
      return ['Save your work, then quit it with Cmd-Q, or right-click its Dock icon and choose Quit.', 'If it is frozen: press Option-Cmd-Esc, select it and choose Force Quit.'];
    case 'tool':
      return ['This is a command-line tool or emulator. Stop it where you started it (Ctrl-C in its terminal, or quit the app that runs it).', 'If you cannot find where it runs, it is safest to leave it.'];
    default:
      return a.advice.isEmpty ? ['This belongs to macOS. It is not something to close.'] : [a.advice, 'This belongs to macOS, so there is nothing to quit.'];
  }
}

/// One plain summary of the ticked apps, to read or copy by hand.
String summary(Resource r, List<AppRow> ticked) {
  final t = ticked.where((a) => !a.system).toList();
  if (t.isEmpty) return 'Nothing ticked.';
  final what = r == Resource.cpu ? 'about ${freedCpu(t).toStringAsFixed(0)}% of a core' : 'about ${mem(freedMb(t))}';
  return 'Quitting ${t.map((a) => a.name).join(', ')} would free $what. Save your work first.';
}
