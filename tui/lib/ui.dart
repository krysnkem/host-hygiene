import 'package:nocterm/nocterm.dart';
import 'layout.dart';

/// True when Home exists, so the finished screen offers the menu instead of only quitting (set once at start).
bool menuAfterDone = false;
List<String> doneKeys() => menuAfterDone ? ['enter, esc or left for the menu ${Gl.i.dot} q quit', 'enter menu / q quit'] : ['enter or q to quit', 'enter / q quit'];

const stepNames = ['Look', 'Pick', 'Confirm', 'Done'];

Component stepper(int cur, {bool narrow = false}) {
  final g = Gl.i, parts = <Component>[];
  for (var i = 0; i < stepNames.length; i++) {
    final done = i < cur, now = i == cur;
    parts.add(Text('${done ? g.check : '${i + 1}'}${narrow ? '' : ' '}${stepNames[i]}',
        style: TextStyle(color: now ? Colors.magenta : (done ? Colors.green : Colors.brightBlack), fontWeight: now ? FontWeight.bold : null)));
    if (i < stepNames.length - 1) parts.add(Text(narrow ? ' ${done ? g.heavy[0] : g.light[0]} ' : (done ? '  ${g.heavy}  ' : '  ${g.light}  '), style: TextStyle(color: done ? Colors.green : Colors.brightBlack)));
  }
  return Row(children: parts);
}

/// A rounded box with a title. Without UTF-8 it is a title rule and a closing rule, same height.
Component box(String title, Component child, {EdgeInsets? padding}) {
  final pad = padding ?? EdgeInsets.symmetric(horizontal: 1);
  if (Gl.i.utf) {
    return Container(decoration: BoxDecoration(border: BoxBorder.all(style: BoxBorderStyle.rounded), title: BorderTitle(text: title)), padding: pad, child: child);
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('-- $title --', style: TextStyle(color: Colors.brightBlack)),
    Padding(padding: pad, child: child),
    Text('--', style: TextStyle(color: Colors.brightBlack)),
  ]);
}

/// [lines] are already wrapped to the speech width.
Component hyCard(String face, Color faceColor, List<String> lines, {String title = 'Hy', bool compact = false}) {
  final row = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(width: 8, child: Text(face, style: TextStyle(color: faceColor, fontWeight: FontWeight.bold))),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final l in lines) Text(l, style: TextStyle(color: Colors.cyan), softWrap: false, overflow: TextOverflow.clip)])),
  ]);
  if (compact) return Padding(padding: EdgeInsets.symmetric(horizontal: 1), child: row);
  return box(title, row, padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1));
}

Component choices(List<String> opts, int sel) => Row(children: [
      for (var i = 0; i < opts.length; i++) ...[
        Text(i == sel ? ' ${Gl.i.arrow} ${opts[i]} ' : '   ${opts[i]} ',
            style: i == sel ? TextStyle(color: Colors.black, backgroundColor: Colors.magenta, fontWeight: FontWeight.bold) : TextStyle(color: Colors.white)),
        SizedBox(width: 2),
      ]
    ]);

/// One dim line that never wraps: the first of [tiers] that fits [w].
/// Every tier also in variants ending with [tag] (the look-switch hint); all tagged variants come before the bare tiers, so the way to switch looks is always shown, at the price of a shorter key list.
/// A tag starting with `* ` is a one-key note (saved, no other look): it replaces the hint until the next key.
/// A tag with a second part (`v look: Name . L choose`) also tries the first part alone, then `v look . L choose`, then a bare `v look`, so the hint always shows how to switch looks.
List<String> tagged(List<String> tiers, String tag) {
  if (tag.startsWith('* ')) return [tag];
  final parts = tag.split(' ${Gl.i.dot} '), short = parts.first;
  final tags = <String>[
    if (tag.isNotEmpty) tag,
    if (parts.length > 2) '$short ${Gl.i.dot} ${parts.last}',   // keep the last hint (m apps) before dropping the middle one
    for (var n = parts.length - 1; n >= 1; n--) parts.sublist(0, n).join(' ${Gl.i.dot} '),
    if (short.startsWith('v look')) ...['v look ${Gl.i.dot} L choose', 'v look'],
  ];
  return [for (var i = 0; i < tiers.length; i++) for (final g in tags) '${tiers[i]} ${Gl.i.dot} $g', ...tiers];
}

Component keys(List<String> tiers, int w, {String tag = ''}) => Text('  ${tier(tagged(tiers, tag), w - 2)}', style: TextStyle(color: Colors.brightBlack), softWrap: false);

/// A plain one-line text cut with an ellipsis at [w].
Component line(String s, int w, {Color? color, bool bold = false}) =>
    Text(fit(s, w), softWrap: false, style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : null));
