// The opening sentence about what kind of developer this machine belongs to. Mirrors scripts/intro.sh.
// Only types the engine detected are ever named. No scoring: counts only decide order and wording.
import 'engine.dart';
import 'voice.dart';

// id -> [plural, singular, mass]
const _names = <String, List<String>>{
  'flutter': ['Flutter apps', 'a Flutter app', 'Flutter'], 'android': ['Android apps', 'an Android app', 'Android'],
  'ios': ['iOS and Swift projects', 'an iOS or Swift project', 'Swift'], 'rn': ['React Native apps', 'a React Native app', 'React Native'],
  'kmp': ['Kotlin Multiplatform projects', 'a Kotlin Multiplatform project', 'Kotlin Multiplatform'],
  'maui': ['MAUI and Xamarin apps', 'a MAUI or Xamarin app', 'MAUI'], 'node': ['Node and TypeScript projects', 'a Node project', 'Node'],
  'frontend': ['frontend monorepos', 'a frontend monorepo', 'frontend monorepo work'], 'python': ['Python projects', 'a Python project', 'Python'],
  'go': ['Go services', 'a Go service', 'Go'], 'rust': ['Rust projects', 'a Rust project', 'Rust'], 'jvm': ['Java and Kotlin projects', 'a Java or Kotlin project', 'JVM'],
  'ruby': ['Ruby projects', 'a Ruby project', 'Ruby'], 'rails': ['Rails apps', 'a Rails app', 'Rails'], 'php': ['PHP projects', 'a PHP project', 'PHP'],
  'dotnet': ['.NET projects', 'a .NET project', '.NET'],
};
String _pl(String k) => _names[k]?[0] ?? '$k projects';
String _sg(String k) => _names[k]?[1] ?? 'a $k project';
String _mass(String k) => _names[k]?[2] ?? k;

String joinAnd(List<String> xs) => xs.length < 2 ? xs.join() : '${xs.sublist(0, xs.length - 1).join(', ')} and ${xs.last}';
/// "A, B and C"; more than three ends with "a few more".
String massList(List<String> ids) => joinAnd(ids.length > 3 ? [_mass(ids[0]), _mass(ids[1]), 'a few more'] : [for (final i in ids) _mass(i)]);

/// Developer types named in the opening sentence (so the tools sentence can skip them) plus the sentence itself.
class TypeSaid { TypeSaid(this.line, this.named); final String line; final Set<String> named; }

TypeSaid sayTypes(Profile p) {
  var ks = [for (final k in p.kinds) if (k.active > 0) (k.id, k.active)];
  var quiet = false;
  if (ks.isEmpty) { ks = [for (final k in p.kinds) if (k.all > 0) (k.id, k.all)]; quiet = true; }
  ks.sort((a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : a.$1.compareTo(b.$1));
  if (ks.isEmpty) {
    final tk = [for (final k in p.kinds) if (k.tool) k.id];
    return tk.isEmpty ? TypeSaid(pick(devTools), {}) : TypeSaid(fill(pick(toolsOnly), {'l': massList(tk)}), tk.toSet());
  }
  final top = ks.first.$2, maj = <String>[], spr = <String>[];
  for (final k in ks) { (k.$2 * 3 >= top && maj.length < 2 ? maj : spr).add(k.$1); }
  final named = {...maj, ...spr};
  if (spr.isEmpty && maj.length == 1) {
    final one = top == 1;
    final pool = quiet ? (one ? quietOne : quietMany) : (one ? oneOne : oneMany);
    return TypeSaid(fill(pick(pool), {'p': _pl(maj[0]), 's': _sg(maj[0]), 'n': '$top'}), named);
  }
  if (maj.length == 1) return TypeSaid(fill(pick(mostly), {'a': _pl(maj[0]), 'b': massList(spr)}), named);
  if (spr.isEmpty) return TypeSaid(fill(pick(mix), {'a': _pl(maj[0]), 'b': _pl(maj[1])}), named);
  return TypeSaid(fill(pick(mix3), {'a': _pl(maj[0]), 'b': _pl(maj[1]), 'c': massList(spr)}), named);
}
