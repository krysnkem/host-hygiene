// Design C, the space map: blocks sized by how big each item is, coloured by class. Collapsed (bars + top items) or expanded (treemap); Tab or e toggles.
import 'package:nocterm/nocterm.dart';
import 'engine.dart';
import 'layout.dart';
import 'look.dart';
import 'spacemap_bars.dart';
import 'spacemap_draw.dart';
import 'spacemap_parts.dart';
import 'state.dart';
import 'ui.dart';

/// Rows around the map: one title above, three below (detail, status, keys), in every stage so the frame never jumps.
const _chrome = 4;
/// Under these map sizes an expanded view folds itself into the bar summary.
const _minMapRows = 7, _minMapCols = 32;

class _Mode { static bool expanded = true; }

class SpaceMapLook extends Look {
  const SpaceMapLook();
  @override String get id => 'spacemap';
  @override String get name => 'Space map';
  @override int get minCols => 40;
  @override int get minRows => 10;
  @override bool get speaks => false;
  @override int listRows(AppState s, Term t) => collapsedList(t.rows - _chrome);
  @override Component build(AppState s, Term t, Actions act) => SpaceMapRoot(s: s, t: t);
}

/// Stateful only to own the layout cache and receive the toggle key; it sits at the root so it survives every stage.
class SpaceMapRoot extends StatefulComponent {
  const SpaceMapRoot({super.key, required this.s, required this.t});
  final AppState s;
  final Term t;
  @override
  State<SpaceMapRoot> createState() => _SpaceMapRootState();
}

class _SpaceMapRootState extends State<SpaceMapRoot> {
  List<Item>? _for;
  int _n = -1, _w = -1, _h = -1;
  List<Blk> _blocks = const [];

  /// Recomputed only when the items or the map size change, never per frame.
  List<Blk> blocks(List<Item> items, int w, int h) {
    if (!identical(_for, items) || _n != items.length || _w != w || _h != h) { _for = items; _n = items.length; _w = w; _h = h; _blocks = layoutMap(items, w, h); }
    return _blocks;
  }

  bool _key(KeyboardEvent k) {
    if (k.logicalKey != LogicalKey.tab && k.logicalKey != LogicalKey.keyE) return false;
    setState(() => _Mode.expanded = !_Mode.expanded);
    return true;
  }

  @override
  Component build(BuildContext context) {
    final s = component.s, t = component.t, w = (t.cols - 2).clamp(1, 400), h = (t.rows - _chrome).clamp(1, 200);
    final auto = h < _minMapRows || w < _minMapCols, open = _Mode.expanded && !auto, st = s.stage;
    final body = st == Stage.look || st == Stage.limits ? SizedBox(height: h.toDouble())
        : open ? MapView(grid: w, h: h, blocks: blocks(s.items, w, h), items: s.items, cur: s.cur)
        : CollapsedView(items: s.items, w: w, h: h, cur: s.cur, top: s.top);
    return Focusable(focused: true, onKeyEvent: _key, child: Padding(padding: EdgeInsets.symmetric(horizontal: 1), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      line(_title(s, w, open, auto), w, color: Colors.brightBlack),
      body,
      ...bottom(s, w, open, auto),
    ])));
  }
}

String _title(AppState s, int w, bool open, bool auto) {
  final mode = open ? 'expanded' : (auto && _Mode.expanded ? 'summary (small)' : 'collapsed');
  final tick = s.items.where((i) => i.on).fold<int>(0, (n, i) => n + i.kb);
  return tier(['Space map  ${s.items.length} item${s.items.length == 1 ? '' : 's'}, ${size(s.totalKb)} found, ${size(tick)} ticked   [$mode]', 'Space map ${size(s.totalKb)} found, ${size(tick)} ticked [$mode]', 'Space ${size(s.totalKb)}, ${size(tick)} ticked', '${size(tick)} ticked'], w);
}

/// A treemap of [blocks]; widget so a cursor move repaints only this.
class MapView extends StatelessComponent {
  const MapView({super.key, required this.grid, required this.h, required this.blocks, required this.items, required this.cur});
  final int grid, h, cur;
  final List<Blk> blocks;
  final List<Item> items;
  @override
  Component build(BuildContext context) {
    final g = Grid(grid, h);
    for (final b in blocks) { drawBlock(g, b, items, cur); }
    if (items.isEmpty) g.put(1, 0, fit('Nothing to clear above the size floor.', grid - 1), TextStyle(color: Colors.brightBlack));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (var y = 0; y < h; y++) g.row(y)]);
  }
}
