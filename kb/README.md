# host-hygiene knowledge base (developer types)

Purpose: the researched evidence behind catalog rows. For each kind of developer
(Flutter/Dart, Android native, iOS native, later Web, Backend) it records what fills
the disk, how big it gets, how to remove it safely and what it costs to get back.

- The catalog (`../catalog/catalog.tsv`) stays the engine's single source of truth.
  Nothing in `kb/` is read by `scan`, `plan` or `apply`. If the KB and the catalog
  disagree about a class or a removal command, the catalog wins and the KB is stale.
- A KB entry with `catalog-id: <id>` documents that catalog row. An entry with
  `catalog-id: none` documents something the engine finds in code (per-project dirs,
  unused Gradle versions) or does not handle yet.
- `~/.claude/flutter-kb` is a different thing: Flutter coding patterns. Do not mix.
- Check with `tests/check-kb.sh` (bash 3.2). Format: `_TEMPLATE.md`. Overview: `INDEX.md`.
- Honesty rule: every size carries a label (`measured here`, `reported online, <URL>`,
  or `(unverified)`). Never present an unlabelled number.
- Adding a catalog row from an entry: see the K3/K3b procedure in `../SKILL.md` ("KB and tests"). Run `tests/check-kb.sh`, `tests/check-catalog-groups.sh` afterwards.
