// Run: dart run tests/console_parse.dart   (exit 1 on any failure)
import 'dart:io';
import 'package:hh_tui/console_cmd.dart';
import 'package:hh_tui/engine.dart';

var bad = 0, n = 0;
void eq(Object? a, Object? b, String what) { n++; if ('$a' != '$b') { bad++; print('FAIL $what: got $a want $b'); } }
Cmd c(String s) => parseCommand(s).cmd;
Item it(int kb, String cls, String path, {bool sup = true}) => Item(kb, cls, 0, 'id', path, '', sup, '', false);

void main() {
  for (final e in {'safe': Cmd.safe, ':safe': Cmd.safe, '  :ASK ': Cmd.ask, 'all': Cmd.all, ':none': Cmd.none, ':go': Cmd.go, ':quit': Cmd.quit, ':q': Cmd.quit, ':help': Cmd.help, '': Cmd.empty, ':': Cmd.empty, '   ': Cmd.empty}.entries) { eq(c(e.key), e.value, 'cmd "${e.key}"'); }
  eq(parseCommand(':sort size').arg, 'size', 'sort size'); eq(parseCommand(':sort PATH').arg, 'path', 'sort path'); eq(c(':sort class'), Cmd.sort, 'sort class');
  eq(c(':sort'), Cmd.error, 'sort no arg'); eq(c(':sort color'), Cmd.error, 'sort bad arg');
  eq(parseCommand(':filter gradle cache').arg, 'gradle cache', 'filter arg'); eq(c(':filter'), Cmd.filter, 'filter clear'); eq(parseCommand(':filter').arg, '', 'filter empty arg');
  for (final bad_ in [':rm -rf ~', ':!ls', ':sh', ':safe now', ':go 1', ':quit now', 'safee', ':q!', ':shell echo hi', ':sort size; ls', ':x\u0001']) { eq(c(bad_), Cmd.error, 'error "$bad_"'); }
  for (final id in ['guided', 'cockpit', 'dashboard', 'spacemap', 'console', 'plain']) { eq(c(':look $id'), Cmd.look, 'look $id'); eq(parseCommand(':LOOK ${id.toUpperCase()}').arg, id, 'look upper $id'); }
  for (final b in [':look', ':look nope', ':look console now', ':look ../x', ':look ;ls', ':lookconsole']) { eq(c(b), Cmd.error, 'look bad "$b"'); }
  eq(parseCommand(':zzzzzzzzzzzzzzzzzzzzzzzz').error.contains('...'), true, 'long verb cut');
  eq(parseCommand(':nope').error, 'unknown command :nope (:help lists them)', 'unknown text');
  // sorting
  final a = it(10, 'safe-regenerable', 'b'), b = it(30, 'ask-first', 'A'), d = it(20, 'safe-regenerable', 'c'), m = it(5, 'ask-first', 'd', sup: false);
  final all0 = [a, b, d, m];
  var l = [a, b, d, m]; sortItems(l, 'size', true); eq(l.map(all0.indexOf).toList(), [1, 2, 0, 3], 'size desc');
  l = [a, b, d, m]; sortItems(l, 'size', false); eq(l.map(all0.indexOf).toList(), [3, 0, 2, 1], 'size asc');
  l = [a, b, d, m]; sortItems(l, 'class', false); eq(l.map(all0.indexOf).toList(), [0, 2, 1, 3], 'class stable');
  l = [a, b, d, m]; sortItems(l, 'path', false); eq(l.map(all0.indexOf).toList(), [1, 0, 2, 3], 'path case-insensitive');
  // filter
  final all = [a, b, d, m];
  eq(visibleIdx(all, ''), [0, 1, 2, 3], 'filter empty'); eq(visibleIdx(all, 'B'), [0], 'filter path ci'); eq(visibleIdx(all, 'manual'), [3], 'filter class'); eq(visibleIdx(all, 'zzz'), <int>[], 'filter none');
  eq(visPos([1, 3], 2), 1, 'visPos next'); eq(visPos([1, 3], 9), 1, 'visPos last'); eq(visPos([], 0), -1, 'visPos empty');
  print('$n checks, $bad failed'); exit(bad == 0 ? 0 : 1);
}
