// Where the user can go from here: the back and forward marks shown beside the key hints. Data only.
import 'state.dart';

class Nav {
  const Nav({this.back = false, this.forward = false});
  /// back: Esc or the left arrow leaves this screen. forward: Enter (or the right arrow on Pick) goes on.
  final bool back, forward;
}

/// What the screen the user is looking at allows. [early]: Home was drawn before the scan finished.
Nav navFor(AppState s, {required bool early}) {
  if (s.screen != null || s.form != null) return const Nav(back: true);
  if (s.onboarding || s.askScan || s.picking) return const Nav(forward: true);
  if (s.home) return const Nav(forward: true);
  switch (s.stage) {
    case Stage.look: return Nav(back: s.homeOn && early);
    case Stage.limits: return const Nav(forward: true);
    case Stage.pick: return Nav(back: s.homeOn, forward: s.items.any((i) => i.on));
    case Stage.confirm: return const Nav(back: true, forward: true);
    case Stage.work: return const Nav();
    case Stage.done: return Nav(back: s.homeOn);
  }
}

/// Set by the app before every build; the shared hint line reads it.
Nav nav = const Nav();
