# KB index

Status: `seeded` = written from what this repo already measured; `researched` = checked
against online sources (URLs in entries); `verified-on-host` = every entry measured here.

| Group | Type | File | Status |
|---|---|---|---|
| mobile | Flutter / Dart | flutter-dart.md | seeded (measured here) |
| mobile | Android native | android-native.md | seeded, partly measured |
| mobile | iOS native | ios-native.md | seeded, partly measured |
| mobile | React Native | react-native.md | seeded from knowledge, NOT web-checked |
| mobile | KMP / MAUI / Xamarin | kotlin-multiplatform-and-maui-xamarin.md | seeded from knowledge, NOT web-checked |
| web | Node / TypeScript | node-typescript.md | seeded, some sources read, partly measured |
| web | Frontend monorepo | web-frontend-monorepo.md | seeded, mostly unverified |
| backend | Python | python.md | seeded, NOT web-checked, partly measured |
| backend | Go | go.md | seeded, NOT web-checked, absent here |
| backend | Rust | rust.md | seeded, NOT web-checked, partly measured |
| backend | JVM | jvm.md | seeded, NOT web-checked, partly measured |
| backend | Ruby / PHP / .NET | ruby-php-dotnet.md | seeded, NOT web-checked, partly measured |
| data/ml | Data / ML | data-ml.md | researched, partly measured (HF cache sizes measured here; Ollama, LM Studio, Torch, Kaggle, W&B absent here) |
| devops | Containers, IaC, cloud CLIs | devops-containers-cloud.md | researched, partly measured (Docker, Vagrant, AWS/gcloud/azure dirs measured here; kube, helm, terraform absent) |
| game | Unity / Unreal / Godot / Blender | game-graphics.md | researched, partly measured (only the absence of every tool was measured; all sizes unverified) |

K3 (2026-11-17): 24 entries across node-typescript, web-frontend-monorepo, python, go, rust, jvm, ruby-php-dotnet,
kotlin-multiplatform and ios-native now carry a catalog row (see STATUS.md "K3 catalog rows"). Those entries are
`catalog-id` linked and were exercised on fake homes with stub tools (tests/check-catalog-groups.sh); NO file's status
changes to `verified-on-host`: sizes for absent tools remain (unverified) and no tool command was run for real.
Entries not turned into rows stay documentation only.

K3b (2026-11-18): the three new files feed 12 catalog rows (hf-hub-cache, hf-xet-cache, torch-hub-cache, wandb-cache, ollama-models,
lmstudio-models, kaggle-cache, kube-cache, helm-cache, vagrant-boxes, unity-upm-global-cache, godot-cache-dir; ollama, lmstudio, kaggle and
vagrant are report-only) plus rows the engine finds in code (jupyter-checkpoints, terraform-project-dirs, terraform-plugin-cache via
TF_PLUGIN_CACHE_DIR, unity-library, unity-temp, godot-project-cache, unreal-intermediate), see STATUS.md "K3b catalog rows". Exercised on fake
homes with stubs only; no file becomes `verified-on-host`. Everything else in these files stays documentation only.

Counts (K6, 2026-11-18): 160 entries in 15 type files; `tests/check-kb.sh` reports 0 failures and 18 warnings (catalog rows without a KB entry, mostly browsers). About 59 entries carry a `catalog-id` other than none (verify: includes the template line); K3 added 24 rows and K3b 12; entries with `catalog-id: none` are documentation only. No file is `verified-on-host`.
