import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'package:hh_tui/app.dart';
import 'package:hh_tui/look_pick.dart';
import 'package:hh_tui/engine.dart';
import 'package:hh_tui/look.dart';

/// `hh_tui --pick-look [--web]`: only the look chooser. Exit 0 = a look was saved, 10 = nothing changed, 2 = no terminal.
class PickApp extends StatefulComponent {
  const PickApp({super.key, required this.web});
  final bool web;
  @override
  State<PickApp> createState() => _PickAppState();
}

class _PickAppState extends State<PickApp> {
  String? current;
  @override
  void initState() { super.initState(); Engine().ui().then((v) { if (mounted) setState(() => current = lookFor(v).id); }); }
  @override
  Component build(BuildContext context) => current == null ? Text('') : LookPicker(current: current!, first: false, startWeb: component.web, onDone: (saved) => shutdownApp(saved == null ? 10 : 0));
}

void main(List<String> args) {
  if (args.contains('--pick-look')) {
    if (!stdin.hasTerminal || !stdout.hasTerminal) { stderr.writeln('hh look needs an interactive terminal.'); exit(2); }
    runApp(PickApp(web: args.contains('--web')));
  } else {
    runApp(const HyApp());
  }
}
