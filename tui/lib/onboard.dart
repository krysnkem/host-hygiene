// First-run onboarding, step 1: Hy says hello and asks what to call the user, and, optionally, what they do.
// Both answers are optional (Enter on an empty line skips one; Esc skips both) and are saved locally through `config set`.
import 'package:nocterm/nocterm.dart';
import 'engine.dart';
import 'layout.dart';
import 'ui.dart';

class Onboard extends StatefulComponent {
  const Onboard({super.key, required this.onDone});
  /// Called once, with the name the user gave (empty when skipped).
  final void Function(String name) onDone;
  @override
  State<Onboard> createState() => _OnboardState();
}

class _OnboardState extends State<Onboard> {
  final eng = Engine();
  int step = 0;
  String text = '', name = '', note = '';
  bool done = false;

  static const _max = 40;

  Future<void> _submit() async {
    final v = text.trim();
    if (step == 0) { name = v; } 
    final ok = v.isEmpty ? true : await eng.setField(step == 0 ? 'name' : 'role', v);
    if (!mounted) return;
    if (!ok) { setState(() => note = 'I could not keep that one. Try something simpler, or press Enter to skip.'); return; }
    if (step == 0) { setState(() { step = 1; text = ''; note = ''; }); } else { _finish(); }
  }

  void _finish() { if (done) return; done = true; component.onDone(name); }

  bool _key(KeyboardEvent k) {
    final lk = k.logicalKey, c = k.character ?? '';
    if (lk == LogicalKey.escape || (k.isControlPressed && lk == LogicalKey.keyC)) { _finish(); return true; }
    if (lk == LogicalKey.enter) { _submit(); return true; }
    if (lk == LogicalKey.backspace) { if (text.isNotEmpty) setState(() { text = text.substring(0, text.length - 1); note = ''; }); return true; }
    if (!k.isControlPressed && c.length == 1 && c.codeUnitAt(0) >= 32 && c != '=' && c.codeUnitAt(0) != 127 && text.length < _max) { setState(() { text += c; note = ''; }); return true; }
    return false;
  }

  @override
  Component build(BuildContext context) {
    final t = Term(), g = Gl.i;
    final q = step == 0 ? 'What should I call you?' : (name.isEmpty ? 'And what do you do?' : 'Nice to meet you, $name. What do you do?');
    final hint = step == 0 ? 'your name' : 'e.g. mobile developer, designer, student';
    return Focusable(focused: true, onKeyEvent: _key, child: Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (t.rows >= 8) line('${g.face('calm')}  Hello there, I\'m Hy, a small tool that keeps your machine tidy.', t.inner, color: Colors.white, bold: true),
      if (t.rows >= 8) line('I find what eats disk, CPU and memory, and only clear it when you say so.', t.inner, color: Colors.cyan),
      SizedBox(height: 1),
      line(q, t.inner, color: Colors.white, bold: true),
      line('${g.arrow} ${text.isEmpty ? '' : text}${g.cursor}${text.isEmpty ? '  ($hint, optional)' : ''}', t.inner, color: Colors.magenta),
      if (note.isNotEmpty) line(note, t.inner, color: Colors.yellow),
      keys(['enter ${step == 0 ? 'next' : 'continue'} ${g.dot} empty enter skips ${g.dot} esc skip both ${g.dot} saved on this Mac only', 'enter ${g.dot} esc skips', 'enter esc'], t.inner),
    ])));
  }
}

/// First-run onboarding, last step: confirm the look that was chosen, then ask before anything is scanned.
class ScanAsk extends StatelessComponent {
  const ScanAsk({super.key, required this.look, required this.name, required this.onAnswer});
  final String look, name;
  /// true = start scanning, false = not now.
  final void Function(bool go) onAnswer;

  @override
  Component build(BuildContext context) {
    final t = Term(), g = Gl.i;
    bool key(KeyboardEvent k) {
      final lk = k.logicalKey;
      if (lk == LogicalKey.enter || lk == LogicalKey.keyY) { onAnswer(true); return true; }
      if (lk == LogicalKey.escape || lk == LogicalKey.keyN || lk == LogicalKey.keyQ || (k.isControlPressed && lk == LogicalKey.keyC)) { onAnswer(false); return true; }
      return false;
    }
    return Focusable(focused: true, onKeyEvent: key, child: Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      line('${g.face('calm')}  ${name.isEmpty ? 'All set.' : 'All set, $name.'} You chose the $look look.', t.inner, color: Colors.white, bold: true),
      if (t.rows >= 8) line('Change it any time: the L key, or `hh look`.', t.inner, color: Colors.cyan),
      SizedBox(height: 1),
      line('Shall I start scanning this machine now?', t.inner, color: Colors.white, bold: true),
      if (t.rows >= 9) line('I only measure sizes. Nothing is removed unless you approve it. It can take a few minutes.', t.inner, color: Colors.cyan),
      line('${g.arrow} Enter: start scanning', t.inner, color: Colors.magenta),
      line('  N or Esc: not now (your choices are saved)', t.inner, color: Colors.brightBlack),
      keys(['enter start ${g.dot} n not now', 'enter ${g.dot} n', 'enter n'], t.inner),
    ])));
  }
}
