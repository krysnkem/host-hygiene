// Small fixed pictures of the five designs for the terminal chooser. Sample data, ASCII drawing only, so they survive HH_ASCII and any font.
// The first character of a row is its colour: g green, y yellow, c cyan, m magenta, d dim, space default. {hy} is the mascot's face.
import 'package:nocterm/nocterm.dart';

/// One line on what a design is for.
const Map<String, String> blurbs = {
  'guided': 'One question per screen with Hy up front. The friendliest start.',
  'cockpit': 'Everything on one screen, like lazygit. The cost is always visible.',
  'dashboard': 'Live and moving, like btop. Best at why the machine is slow.',
  'spacemap': 'Size is shape, like a treemap. See where your space went.',
  'console': 'Compact and keyboard-first, like k9s. Hy sits in the status line.',
};

const Map<String, List<String>> previews = {
  'guided': [
    'g  1 Look ===== 2 Pick --- 3 Confirm --- 4 Done',
    ' +- Hy -----------------------------------+',
    'c| {hy} I found 5 things safe to clear.  |',
    'g|   4.2G  my-app/build                   |',
    'g|   2.7G  web-shop/build                  |',
    ' +----------------------------------------+',
    'm   > Take me through them     Not now',
    'd   enter choose | arrows move | esc back',
  ],
  'cockpit': [
    ' +- host-hygiene -------------------------+',
    'c| {hy} All good. 19 GiB free, load 7.2  |',
    ' +- Kinds -----+- Safe to clear --+- About --+',
    'g| > Safe   5  | > [x] 4.2G build | build    |',
    'y|   Ask    7  |   [x] 2.7G build | git: yes |',
    'd|   Manual 2  |   [ ] 1.4G build | slower   |',
    ' +-------------+------------------+----------+',
    'd  space tick | a all safe | enter review',
  ],
  'dashboard': [
    ' +- Disk ---------------+- Load (10 cores) ---+',
    ' | 19.1 GiB free of 460 | now 7.2  limit 8    |',
    'g| ##############...... | .:::=#%=::.==:.     |',
    ' +- Heaviest -----------+- Reclaimable -------+',
    'r| qemu-system    87%   | safe       21.9G    |',
    'y| Code          108%   | ask-first  83.7G    |',
    ' +----------------------+---------------------+',
    'd  tab focus | c clean | g can I build?',
  ],
  'spacemap': [
    'd  ~ / everything   460 GiB, 19 GiB free',
    'y+- Gradle 19.1G -------+- Emulators 15.4G ---+',
    'y| modules-2   4.6G     | Pixel_5     5.8G    |',
    'y| 8.12        3.8G     | Pixel_8     5.1G    |',
    'g+- build/ 8.3G --------+- Caches 16.5G ------+',
    'g| my-app      4.2G     | Google      8.0G    |',
    'g+----------------------+---------------------+',
    'd  arrows move | enter open | b back',
  ],
  'console': [
    'm  host-hygiene > space > gradle     {hy} all good',
    'd  NAME         SIZE   CLASS       AGE',
    'y  > modules-2   4.6G   ask-first   10d',
    'y    8.12        3.8G   ask-first   34d',
    'y    7.6.3       2.1G   ask-first  210d',
    'g    9.8.1       0.7G   unused      13d',
    'd  d describe | x clear | / filter | ? help',
    'm  :clean safe_',
  ],
};

const _colors = {'g': Colors.green, 'y': Colors.yellow, 'c': Colors.cyan, 'm': Colors.magenta, 'd': Colors.brightBlack, 'r': Colors.red};

/// The picture for [id], one row per line, cut to [w] columns. [face] replaces {hy}.
class LookPreview extends StatelessComponent {
  const LookPreview({super.key, required this.id, required this.face, required this.w});
  final String id, face;
  final int w;

  @override
  Component build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final l in previews[id] ?? const <String>[])
          Text(_cut(l.substring(1).replaceAll('{hy}', face), w),
              softWrap: false, style: TextStyle(color: _colors[l[0]])),
      ]);

  static String _cut(String s, int w) => s.length <= w ? s : s.substring(0, w);
}
