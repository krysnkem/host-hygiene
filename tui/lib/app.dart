import 'dart:async';
import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'control.dart';
import 'layout.dart';
import 'look.dart';
import 'resource_view.dart';
import 'form_view.dart';
import 'home_view.dart';
import 'look_pick.dart';
import 'onboard.dart';
import 'state.dart';
import 'views.dart';

class HyApp extends StatefulComponent {
  const HyApp({super.key});
  @override
  State<HyApp> createState() => _HyAppState();
}

class _HyAppState extends State<HyApp> {
  final s = AppState();
  late final Controller c = Controller(s, setState);
  Timer? timer;
  StreamSubscription<MouseEvent>? mouse;
  StreamSubscription<ProcessSignal>? winch;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      // Redraw only when something on screen moves: speech typing, the look/work spinner, or a blink edge. Idle screens (pick, confirm, limits after speech) stay still.
      final busy = !s.speechDone || s.stage == Stage.look || s.stage == Stage.work;
      c.advance();
      if (busy || s.tick % 70 == 0 || s.tick % 70 == 3) setState(() {});
    });
    // A resize repaints at once: Term() reads the size at build time, so a rebuild is all it takes (no polling).
    try { winch = ProcessSignal.sigwinch.watch().listen((_) => setState(() {})); } catch (_) {}
    try { mouse = TerminalBinding.instance.mouseEvents.listen(c.wheel); } catch (_) {}
    c.start();
  }

  @override
  void dispose() { timer?.cancel(); mouse?.cancel(); winch?.cancel(); super.dispose(); }

  @override
  Component build(BuildContext context) {
    final t = Term();
    if (t.tooSmall) return Focusable(focused: true, onKeyEvent: c.key, child: TooSmallView(t: t));
    if (s.screen != null) return ResourceView(script: c.eng.script, start: s.screen!, onClose: () { setState(() => s.screen = null); c.refreshIgnored(); });
    if (s.onboarding) return Onboard(onDone: (n) => setState(() { s.onboarding = false; s.userName = n; c.onboarded?.complete(); }));
    if (s.askScan) return ScanAsk(look: lookFor(s.lookId).name, name: s.userName, onAnswer: (go) { if (!go) { shutdownApp(); return; } setState(() => s.askScan = false); c.scanAnswered?.complete(); });
    if (s.picking) return LookPicker(current: s.lookId, first: s.pickFirst, startWeb: false, onDone: (id) => setState(() { s.picking = false; s.pickFirst = false; s.askLook = false; c.lookAnswered?.complete(); if (id != null) { s.lookId = lookFor(id).id; s.speaks = lookFor(id).speaks; s.note = '* look: ${lookFor(id).name}, saved'; } }));
    if (s.form != null) return FormView(s: s, onLook: () => setState(() { s.picking = true; s.pickFirst = false; }), onClose: (r) { setState(() { s.form = null; if (r != null) s.reading = r; }); c.refreshIgnored(); });
    if (s.home) return Focusable(focused: true, onKeyEvent: c.homeKey, child: HomeView(s: s, t: t));
    return Focusable(focused: true, onKeyEvent: c.key, child: c.look.build(s, t, Actions(tap: c.click)));
  }
}
