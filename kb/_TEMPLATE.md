# <Developer type>

One file per developer type. Three fixed sections after the entries, in this order.
A checker (`tests/check-kb.sh`) parses the entry blocks: keep the line prefixes exact.

## Entries

One `### <id>` block per artifact kind. Every line below is a single `- key: value` line
(value may be long, never multi-line). All keys are required.

### <id>
- what: one sentence, what the artifact is
- catalog-id: <id of the row in catalog/catalog.tsv, or `none` if there is no row>
- paths: usual path(s), `~` allowed; globs ok
- size: <typical size> (measured here | reported online, <URL> | (unverified))
- class: safe-regenerable | ask-first | never
- removal: the tool's own command; `rm-verified`; `report-only`; or `none` (never remove)
- regen: what it costs to get back (time, network, data lost)
- growth: how it grows, and a suggested budget (label a budget `(suggested)`)
- source: `measured on this host 2026-11-17`, a URL, or `(unverified)`

Rules:
- id: lowercase kebab-case. If a catalog row exists the id MUST equal the catalog id.
- class mirrors POLICY.md section 3. Never invent a class. When unsure use `ask-first`.
- Dates are ISO. Say `measured on this host <date>` only if it really was measured.
- Anything not measured or sourced says `(unverified)`.

## Developer habits
What this kind of developer typically does that fills the disk.

## Signals
Files, dirs and commands that identify this developer type (used later by profile detection).

## Not covered / open questions
What the KB does not know yet.
