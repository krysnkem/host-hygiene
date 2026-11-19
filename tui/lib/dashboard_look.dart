// Design B, the dashboard: live tiles (disk, load, heaviest processes) over one big tile that holds the pick list, then confirm, progress and done in the same frame.
import 'dart:async';
import 'package:nocterm/nocterm.dart';
import 'dashboard_data.dart';
import 'dashboard_parts.dart';
import 'engine.dart';
import 'layout.dart';
import 'look.dart';
import 'plain_look.dart';
import 'state.dart';
import 'ui.dart';
import 'views.dart';

class DashboardLook extends Look {
  const DashboardLook();
  @override String get id => 'dashboard';
  @override String get name => 'Dashboard';
  @override int get minCols => 60;
  @override int get minRows => 14;
  @override bool get speaks => false;
  @override
  int listRows(AppState s, Term t) => DashGeo(t).list;
  @override
  Component build(AppState s, Term t, Actions act) => DashLive(s: s, t: t, act: act);
}

/// Owns the poll timer, so it exists exactly while the look is mounted (the plain fallback or another look unmounts it, which cancels it) and not in the work stage.
class DashLive extends StatefulComponent {
  const DashLive({super.key, required this.s, required this.t, required this.act});
  final AppState s;
  final Term t;
  final Actions act;
  @override
  State<DashLive> createState() => _DashLiveState();
}

class _DashLiveState extends State<DashLive> {
  static const every = Duration(seconds: 10);
  late final DashPoller poller = DashPoller(Engine().script);
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    poller.seed(component.s.g);
    _resume();
  }

  @override
  void didUpdateComponent(DashLive old) {
    super.didUpdateComponent(old);
    final work = component.s.stage == Stage.work;
    if (work && _timer != null) { _timer!.cancel(); _timer = null; }
    if (!work && _timer == null) _resume();
  }

  void _resume() { _timer = Timer.periodic(every, (_) => _poll()); _poll(); }

  Future<void> _poll() async {
    if (_busy || !mounted) return;
    _busy = true;
    try {
      final changed = await poller.poll();
      if (changed && mounted && _timer != null) setState(() {});
    } finally { _busy = false; }
  }

  @override
  void dispose() { _timer?.cancel(); _timer = null; super.dispose(); }

  @override
  Component build(BuildContext context) {
    final s = component.s, t = component.t, g = DashGeo(t), st = s.stage, lim = Lim(s.g);
    final live = st == Stage.work ? 'paused' : 'live ${every.inSeconds} s';
    return Padding(padding: EdgeInsets.symmetric(horizontal: 1), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(fit('host-hygiene ${Gl.i.dot} Dashboard ${Gl.i.dot} ${stageNames[st.index]} ${Gl.i.dot} $live', t.inner), softWrap: false, style: TextStyle(color: Colors.brightBlack)),
      DashGauges(g: g, d: poller.d, lim: lim),
      DashSlot(s: s, t: t, g: g, act: component.act),
    ]));
  }
}

/// The big tile: whatever the stage asks for, so the frame never changes shape.
class DashSlot extends StatelessComponent {
  const DashSlot({super.key, required this.s, required this.t, required this.g, required this.act});
  final AppState s;
  final Term t;
  final DashGeo g;
  final Actions act;
  @override
  Component build(BuildContext context) {
    final st = s.stage, spin = Gl.i.spin[s.tick % 10], z = EdgeInsets.zero, gap = t.compact ? 0 : 2;
    if (st == Stage.pick) return PickTile(s: s, t: t, win: g.list, onTap: act.tap);
    if (st == Stage.look) return box('Looking', _w(line('  $spin Looking around your machine', t.inner, color: Colors.cyan)), padding: z);
    if (st == Stage.limits) return box('Limits', _w(LimitsView(t: t, sel: s.sel, g: s.g)), padding: z);
    if (st == Stage.confirm) return box('Confirm', _w(ConfirmView(t: t, chosen: s.chosen, cap: (g.slot - (4 + gap + (s.chosen.any((i) => !i.safe) ? 1 : 0))).clamp(1, 12), sel: s.sel)), padding: z);
    if (st == Stage.work) return box('Progress ${s.finished}/${s.total}', _w(WorkView(t: t, spin: spin, total: s.total, finished: s.finished, current: s.current, results: s.results, cap: (g.slot - 2).clamp(0, 5))), padding: z);
    return box('Done', _w(DoneView(t: t, ran: s.ran, before: s.freeBefore, after: s.freeAfter, manual: s.items.where((i) => !i.supported).length, problems: s.problems)), padding: z);
  }

  /// Full width, so the tile keeps its shape from one stage to the next.
  Component _w(Component c) => SizedBox(width: t.inner.toDouble(), child: c);
}

/// Reclaimable items with ticks and class tags (colours as in the guided look), the cost of the one under the cursor, the running total and the keys.
class PickTile extends StatelessComponent {
  const PickTile({super.key, required this.s, required this.t, required this.win, required this.onTap});
  final AppState s;
  final Term t;
  final int win;
  final void Function(int) onTap;
  /// One list row, padded to the tile width so the box spans the screen.
  String _row(int i, int nameW, int w) {
    final it = s.items[i], r = '${i == s.cur ? Gl.i.arrow : ' '} ${it.supported ? (it.on ? '[x]' : '[ ]') : '   '} ${size(it.kb).padLeft(6)}  ${it.safe ? 'safe  ' : (it.supported ? 'ask   ' : 'manual')} ${fitPath(it.name, nameW)}';
    return r + ' ' * (w - cells(r)).clamp(0, 400);
  }

  @override
  Component build(BuildContext context) {
    final g = Gl.i, items = s.items, top = s.top, end = (top + win).clamp(0, items.length), nameW = (t.cols - 8 - 21).clamp(6, 300);
    int kb(bool Function(Item) f) => items.where(f).fold(0, (n, i) => n + i.kb);
    final pos = items.length > win ? '  (${top + 1}-$end of ${items.length})' : '', sum = 'safe ${size(kb((i) => i.safe && i.supported))} ${g.dot} ask ${size(kb((i) => !i.safe && i.supported))} ${g.dot} manual ${size(kb((i) => !i.supported))}';
    final title = tier(['Reclaimable  $sum$pos', 'Reclaimable$pos', 'Reclaim$pos'], t.cols - 8);
    final on = items.where((i) => i.on), more = '${top > 0 ? '${g.up} ' : ''}${end < items.length ? g.down : ''}', c = items.isEmpty ? null : items[s.cur];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      box(title, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = top; i < end; i++)
          GestureDetector(
            onTap: () => onTap(i),
            child: Text(_row(i, nameW, t.cols - 6),
                softWrap: false, style: TextStyle(color: !items[i].supported ? Colors.brightBlack : (items[i].safe ? Colors.green : Colors.yellow), backgroundColor: i == s.cur ? Color.fromRGB(42, 46, 72) : null)),
          ),
        for (var i = end - top; i < win; i++) SizedBox(height: 1),
      ])),
      line(c == null ? '' : '  ${c.supported ? 'Cost: ${c.note}' : 'By hand: ${c.cmd}'}', t.inner, color: Colors.brightBlack),
      Text(tier(['  Selected: ${on.length} item(s), about ${size(on.fold(0, (n, i) => n + i.kb))}   $more', '  ${on.length} selected, ${size(on.fold(0, (n, i) => n + i.kb))} $more', '  ${on.length} sel'], t.inner), softWrap: false, style: TextStyle(color: Colors.magenta, fontWeight: FontWeight.bold)),
      keys(['${g.ud} move ${g.dot} space tick ${g.dot} PgUp/PgDn ${g.dot} s safe ${g.dot} f ask-first ${g.dot} a all ${g.dot} n none ${g.dot} enter continue ${g.dot} q quit', '${g.ud} ${g.dot} space ${g.dot} s safe ${g.dot} f ask ${g.dot} a all ${g.dot} n none ${g.dot} enter ${g.dot} q quit', 'space s a f n enter q'], t.inner, tag: lookKey(s)),
    ]);
  }
}
