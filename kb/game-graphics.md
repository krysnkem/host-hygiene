# Game / graphics developer (Unity, Unreal, Godot, Blender)

Researched 2026-11-18 with WebSearch and fetches of official docs. Nothing from these tools was present on this Mac
(measured here: no ~/Library/Caches/Unity, ~/Library/Unity, Godot, Blender, Epic dirs, /Applications/Unity), so every size is unlabelled-by-measurement and marked (unverified).
Steam is not a developer tool and is deliberately skipped. Xcode game-asset builds overlap `ios-native.md` (xcode-derived, xcode-archives): see there.

## Entries

### unity-project-library
- what: Unity per-project Library/ folder, the cache of imported, game-ready asset versions (plus script assemblies and artifacts)
- catalog-id: none
- paths: <project>/Library
- size: (unverified); routinely multi-GB on large projects (unverified)
- class: ask-first
- removal: engine finds it in code: ask-first, only beside ProjectSettings/ProjectVersion.txt, refused while a Unity Editor runs
- regen: Unity rebuilds it from Assets/ and ProjectSettings/ on next open, but a full reimport can take minutes to hours on big projects, plus a script recompile
- growth: grows with project asset count and every platform switch; one per project, stale ones remain after the project is abandoned
- source: reported online, https://docs.unity3d.com/2020.2/Documentation/Manual/AssetWorkflow.html (fetched 2026-11-18: "you can safely delete the Library folder" when the project is not open; do not version-control it)

### unity-project-temp-logs
- what: Unity per-project Temp/ and Logs/ (and obj/) scratch folders created by the Editor
- catalog-id: none
- paths: <project>/Temp, <project>/Logs, <project>/obj
- size: (unverified); normally small (unverified)
- class: safe-regenerable
- removal: engine finds ONLY Temp in code (ask-first, same marker); Logs and obj are NOT offered (removability unverified)
- regen: re-created on next Editor launch; Logs hold old Editor and package-manager logs only
- growth: Temp is cleared by the Editor on exit; Logs stays small
- source: reported online, https://docs.unity3d.com/2020.2/Documentation/Manual/AssetWorkflow.html (fetched 2026-11-18: Temp must not be backed up or versioned; Logs and obj are not described there, so removability of Logs/obj is (unverified))

### unity-upm-global-cache
- what: Unity Package Manager global cache of downloaded registry packages (db) and Git LFS files
- catalog-id: unity-upm-global-cache
- paths: ~/Library/Caches/Unity/upm
- size: capped at 10 GB by Unity (reported online, https://docs.unity.com/en-us/engine/current/manual/packages-list/package-manager-caches/upm-cache); actual size here (unverified)
- class: safe-regenerable
- removal: rm-verified (contents of the folder, Editor closed; the page documents no clear command, this is inferred from the page's cache description)
- regen: packages are re-downloaded from their registries on next resolve; offline installs of uncached packages fail until then
- growth: Unity evicts least-recently-used packages at the 10 GB limit; suggested budget: leave alone, or clear if under disk pressure (suggested)
- source: https://docs.unity.com/en-us/engine/current/manual/packages-list/package-manager-caches/upm-cache (fetched 2026-11-18)

### unity-asset-store-cache
- what: downloaded Asset Store .unitypackage files kept for reuse across projects
- catalog-id: none
- paths: ~/Library/Unity/Asset Store-5.x (older manuals: ~/Library/Unity/Asset Store); ~/Library/Unity/Asset Store*
- size: (unverified)
- class: ask-first
- removal: report-only (the docs do not state it is safe to delete; the Package Manager window is the documented way to manage purchased packages)
- regen: re-downloadable from the Asset Store while the licence is still owned; needs network and a Unity login
- growth: one folder per publisher, grows with every download or update; suggested budget: review per vendor (suggested)
- source: reported online, https://docs.unity3d.com/2022.3/Documentation/Manual/AssetStorePackages.html (fetched 2026-11-18); safe-to-delete claim (unverified)

### unity-hub-editors
- what: Unity Editor installs managed by Unity Hub, one folder per editor version
- catalog-id: none
- paths: /Applications/Unity/Hub/Editor/<version> (default, from general knowledge), ~/Applications/Unity (alternate location)
- size: (unverified); several GB per version incl. platform modules (unverified)
- class: ask-first
- removal: Unity Hub, Installs tab, Uninstall on the version (keeps Hub records consistent); do not rm by hand
- regen: re-download the editor and its modules from Unity Hub; projects pinned to that exact version need it
- growth: one per editor version and per added build-support module; suggested budget: keep only versions that open a live project (suggested)
- source: https://docs.unity.com/en-us/hub (fetched 2026-11-18; the page does not state the path or the uninstall steps, so both are (unverified) beyond general knowledge)

### unreal-ddc
- what: Unreal Derived Data Cache, local cache of data derived from .uasset content (shaders, textures); UE 5.4+ default is the Zen store
- catalog-id: none
- paths: ~/Library/Application Support/Epic/UnrealEngine (reported by a forum user, (unverified) for current versions); Zen: AppSettingsDir/Zen/Data; <project>/DerivedDataCache
- size: (unverified); the docs say derived data is large (reported online, https://dev.epicgames.com/documentation/unreal-engine/using-derived-data-cache-in-unreal-engine)
- class: ask-first
- removal: report-only (let the editor garbage-collect; the legacy filesystem DDC self-deletes after an 8-day cleanup period; Zen and cloud DDC do their own GC; set a new path in Editor Preferences > General > Global > Derived Data Cache). Manual rm: (unverified) on Mac
- regen: the docs call it disposable ("UE can regenerate it anytime from .uasset files") but a cold DDC means long shader and asset rebuilds and editor stalls; a team Shared DDC deletion makes the next user pay. Never point a shared DDC at a local path
- growth: grows with project content and engine versions; old engine versions leave stale caches. Suggested budget: clean per old engine version (suggested)
- source: https://dev.epicgames.com/documentation/unreal-engine/using-derived-data-cache-in-unreal-engine (fetched 2026-11-18); Mac path from https://forums.unrealengine.com/t/how-do-i-delete-ddc-on-mac-os/471732 (fetched 2026-11-18, forum, reported online)

### unreal-project-intermediate-saved-binaries
- what: Unreal per-project build and runtime folders: Intermediate (temp build files, shaders), Saved (autosaves, .ini config, logs), Binaries (compiled output)
- catalog-id: none
- paths: <project>/Intermediate, <project>/Saved, <project>/Binaries
- size: (unverified); Intermediate commonly the largest of the three (unverified)
- class: ask-first
- removal: engine finds ONLY Intermediate in code (ask-first, beside a *.uproject, refused while UnrealEditor runs); Binaries (unverified) and Saved (never) are NOT offered
- regen: Intermediate and Binaries rebuild on next compile (full C++ recompile and shader compile can take tens of minutes to hours); project files may need regenerating. Epic's directory page says Intermediate and Saved "can be deleted and rebuilt" for game projects but does not say Binaries is deletable (Binaries removability: (unverified) officially, forum-reported only)
- growth: grows with every build config and platform; suggested budget: clean on archive (suggested)
- source: reported online, https://dev.epicgames.com/documentation/unreal-engine/unreal-engine-directory-structure (fetched 2026-11-18)

### unreal-saved-user-data
- what: Saved/ contains autosaves, unsaved-work recovery, per-project config and crash logs; the only copy of unsubmitted local work may live here
- catalog-id: none
- paths: <project>/Saved
- size: (unverified)
- class: never
- removal: none (inspect manually; it can hold autosaved levels not yet committed)
- regen: autosaves and local settings are lost, not regenerated
- growth: autosave and log accumulation; suggested budget: review per project (suggested)
- source: reported online, https://dev.epicgames.com/documentation/unreal-engine/unreal-engine-directory-structure (fetched 2026-11-18; "Saved holds autosaves, .ini and logs"); never-class is this KB's conservative choice per the task brief

### unreal-engine-installs-vault
- what: Epic Games Launcher engine installs and the Vault Cache of downloaded Marketplace/Fab content
- catalog-id: none
- paths: /Users/Shared/Epic Games/UE_<version>; /Users/Shared/UnrealEngine/Launcher/VaultCache; ~/Library/Caches/EpicGamesLauncher; ~/Library/Caches/Unreal Engine
- size: (unverified); a single engine install is tens of GB (unverified)
- class: ask-first
- removal: uninstall engines from the Epic Games Launcher; Vault Cache can be moved in launcher settings; do not rm /Users/Shared/Epic Games by hand
- regen: re-download from the launcher (engines tens of GB; Vault assets re-sync, needs network and account)
- growth: one install per engine version; Vault grows with every asset downloaded; suggested budget: keep engines that match live projects (suggested)
- source: reported online, forum and third-party posts only, https://forums.unrealengine.com/t/how-do-i-move-the-vault-location/287367 (found via WebSearch 2026-11-18, not fetched); all paths (unverified) against current launcher

### godot-project-cache
- what: Godot per-project .godot/ folder, auto-created cache of imported assets, editor state and shader cache
- catalog-id: none
- paths: <project>/.godot (imported/, editor/, shader_cache/, plus uid and class caches)
- size: (unverified)
- class: ask-first
- removal: engine finds it in code: ask-first, only beside project.godot, refused while Godot runs
- regen: reimport of every asset on next open, slow for large projects; forum reports of UID or tileset reference confusion after deletion, so back up first. Official docs only say it "stores various project cache data" and should be ignored by VCS; whether deletion is safe is (unverified) officially, forum-reported only
- growth: grows with imported asset count; one per project
- source: https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html (fetched 2026-11-18); deletion advice from forum search results, reported online

### godot-editor-data-templates
- what: Godot editor data per user: export templates and editor settings
- catalog-id: none
- paths: ~/Library/Application Support/Godot (export templates under templates/<version>)
- size: (unverified); templates are large per version, docs give no figure (unverified)
- class: ask-first
- removal: Editor > Manage Export Templates (documented management UI); manual rm of an old version folder is (unverified) in the docs
- regen: re-download templates per version when exporting; editor settings file is user config and is lost if the whole folder is removed
- growth: one templates folder per Godot version ever exported with; suggested budget: remove versions no project uses (suggested)
- source: https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html (fetched 2026-11-18: editor data and export templates under ~/Library/Application Support/Godot); https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html (fetched 2026-11-18: install location not stated)

### godot-cache-dir
- what: Godot user cache directory
- catalog-id: godot-cache-dir
- paths: ~/Library/Caches/Godot
- size: (unverified)
- class: safe-regenerable
- removal: rm-verified (Godot closed; the docs say the data can be removed safely when Godot is closed)
- regen: re-created by Godot on demand
- growth: small to moderate; suggested budget: leave alone (suggested)
- source: https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html (fetched 2026-11-18)

### blender-user-data-and-temp
- what: Blender per-version user config (preferences, add-ons, extensions) and the temp directory used for render layers, physics cache, copy-paste buffer, autosaves and crash logs
- catalog-id: none
- paths: ~/Library/Application Support/Blender/<version>; temp: User Preferences > File Paths, else /tmp/ (autosave goes to the temp dir on non-Windows)
- size: (unverified)
- class: ask-first
- removal: report-only (old version folders under Application Support hold that version's preferences and add-ons; delete one only for a Blender version you no longer use); temp files are removed by the OS or by hand when Blender is closed
- regen: preferences and add-ons are user config, re-created as defaults; temp cache re-generated on demand; autosaves lost (could be unsaved work)
- growth: one config folder per Blender version used; temp grows with big simulations/renders; suggested budget: clean old version folders yearly (suggested)
- source: reported online, https://docs.blender.org/manual/en/4.2/advanced/blender_directory_layout.html (seen via WebSearch snippet 2026-11-18; direct fetch returned only navigation text, so details are partly (unverified))

### shader-and-gpu-caches
- what: engine and OS shader caches created by game engines (Unity Library/ShaderCache, Unreal Intermediate/ShaderAutogen and DDC shaders, Godot .godot/shader_cache)
- catalog-id: none
- paths: inside <project>/Library, <project>/Intermediate, <project>/.godot/shader_cache; DDC (see unreal-ddc)
- size: (unverified)
- class: ask-first
- removal: rm-verified for the Godot shader_cache subfolder only per forum report; for Unity and Unreal remove the parent entry above, not the subfolder
- regen: shaders recompile on next launch or load; first run stutters or is slow
- growth: grows with materials and target platforms
- source: Epic directory page states shaders live in Intermediate (https://dev.epicgames.com/documentation/unreal-engine/unreal-engine-directory-structure, fetched 2026-11-18); Unity and Godot specifics (unverified)

## Developer habits
Game developers keep many engine versions side by side (Unity editors via Hub, Unreal engine installs, Godot templates) and one fat project per game; each project carries a regenerable cache (Library/, DerivedDataCache, Intermediate, .godot) that is not version-controlled, so dead projects keep it. Asset Store and Vault downloads accumulate. Xcode builds for iOS targets add DerivedData and archives (see ios-native.md).

## Signals
- Dirs: Assets/ + ProjectSettings/ + Packages/ + Library/ (Unity); *.uproject with Config/ Content/ Source/ (Unreal); project.godot and .godot/ (Godot); *.blend files
- Paths: /Applications/Unity/Hub, ~/Library/Unity, ~/Library/Caches/Unity, /Users/Shared/Epic Games, ~/Library/Application Support/Godot, ~/Library/Application Support/Blender
- Apps/commands: Unity Hub, Unity, UnrealEditor, Epic Games Launcher, Godot, Blender

## Not covered / open questions
- No tool from this group is installed here, so no size and no removal command was exercised.
- Unity Hub install path, Logs/obj removability, Unreal Mac DDC path, Binaries deletability, Godot .godot deletion safety, Blender cache subpaths are unconfirmed in official docs.
- Unity Cache Server / Accelerator, Unity 6 Build Profiles output, Unreal Zen Mac data path, Blender extension repository cache, Unity "Library/Unity/Asset Store*" in newer Hubs: not researched.
