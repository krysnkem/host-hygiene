// Hy's voice: phrase pools, one picked at random. Add lines freely.
import 'dart:io';
import 'dart:math';
final _r = Random(int.tryParse(Platform.environment['HH_SEED'] ?? ''));
String pick(List<String> xs) => xs[_r.nextInt(xs.length)];
String fill(String t, Map<String, String> v) { v.forEach((k, x) => t = t.replaceAll('{$k}', x)); return t; }

const hello = ["Hi, I'm Hy. Give me a moment to look around your machine.", "Hey there. Let me have a quick look at what lives on this machine.", "Hello! I'll take a peek at how your machine is set up."];
const nonDev = ["Looks like an everyday machine to me. No developer tools that I can see.", "No coding toolchains that I can spot, so I'll treat this as an everyday machine."];
const oneMany = ["Looks like {p} are your thing. I count {n} you've touched lately.", "So you build {p}. {n} of them have seen activity lately.", "I can see you work on {p}, with {n} of them active in the last three months."];
const oneOne = ["I can see {s} that you've been working on lately.", "Looks like you've got {s} on the go.", "So you build things like {s}, and you've touched it lately."];
const quietMany = ["I found {p}, though none were touched in the last three months.", "There are {p} here, all quiet lately."];
const quietOne = ["I found {s}, though it has been quiet for the last three months.", "There's {s} here, nothing touched lately."];
const mostly = ["I see mostly {a}, with some {b} sprinkled in.", "Looks like you mostly work on {a}, with a little {b} on the side.", "{a} are the star here, with a bit of {b} around them.", "You're mostly into {a}, and there's some {b} too."];
const mix = ["I see a real mix here: {a} and {b} side by side.", "Looks like you work on both {a} and {b}, nice.", "You split your time between {a} and {b}, from what I can see."];
const mix3 = ["You're a real all-rounder: mostly {a} and {b}, with a bit of {c}.", "I see mostly {a} and {b}, plus a bit of {c}.", "It's a proper mix here: mostly {a} and {b}, with some {c} around the edges."];
const toolsOnly = ["I don't see any projects yet, but the tools here point to {l}.", "No projects that I can find, though your toolbox hints at {l}."];
const devTools = ["I can see a developer setup here, judging by the tools.", "This looks like a developer machine, going by the tools I can see."];
const tools = ["Around that, I also found {t}.", "Your toolbox also has {t}.", "I also spotted {t}."];
const heavy = ["You also have {x}. Those tend to be the big ones.", "I see {x}. Those are usually the heaviest items on a developer machine."];
const state = ["Right now you have {f} GiB free and the load is {l}.", "For the record: {f} GiB free, load {l}."];
const found = ["I found {n} that are safe to clear.", "There are {n} here I can clear safely."];
const askOnly = ["Nothing here is safe to clear without asking, but {n} need your call. Each shows its cost.", "I found {n} you may want to clear. They cost something to rebuild, so you decide."];
const spotless = ["Spotless. Nothing worth clearing.", "Clean as a whistle. Nothing to clear."];
const asking = ["Nothing is removed until you say yes.", "Take your time. You decide."];
const working = ["On it. One item at a time...", "Clearing, nice and careful..."];
const doneLines = ["Nice, lighter already.", "Room to breathe again.", "Tidy."];
const tight = ["Heads up, things are getting tight.", "I'd go easy on heavy work for now."];
const stopLines = ["Space is critically low. Please don't start a build yet.", "We're at the hard stop. Let's free some space first."];
const calm = ["All good here.", "Everything looks healthy.", "Smooth sailing."];
