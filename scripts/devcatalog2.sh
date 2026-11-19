# host-hygiene catalog support, K3b (data/ml, devops, game). SOURCED by host-hygiene.sh after devcatalog.sh. Functions only. bash 3.2.
#   dc2_has NEEDS         gating for the needs ids ml / devops / game (dir- or tool-based), called by dc_has
#   dc2_project_rows P    scan: per git project, .ipynb_checkpoints (jupyter-checkpoints) and .terraform (terraform-project-dirs, git-ignored only)
#   dc2_extra_rows        scan: $TF_PLUGIN_CACHE_DIR (terraform-plugin-cache) and game projects found by marker files (no git needed):
#                           ProjectSettings/ProjectVersion.txt -> Library, Temp   | project.godot -> .godot   | *.uproject -> Intermediate
#   dc2_classify T        apply: recognises those same paths again from their markers, sets CLS REM CATID WHY (rc 0), rc 1 = not mine, rc 2 = refuse (WHY)
#   dc2_guard ID          apply: running-process guards (editor / terraform running), sets DWHY, rc 1 = refuse
# NOT handled, on purpose: Unity Logs/obj, Unreal Binaries/Saved (removability unverified or user data), Godot editor data, any docker volume,
# VirtualBox VMs, mlflow runs, dvc cache. Report-only rows live in catalog.tsv and are refused by classify in host-hygiene.sh.

dc2_has() {
  case "$1" in
    ml) dc_have ollama || dc_have hf || dc_have wandb || dc_have lms || dc_dir "$HOME/.cache/huggingface" || dc_dir "$HOME/.cache/torch" || dc_dir "$HOME/.cache/wandb" \
          || dc_dir "$HOME/.ollama" || dc_dir "$HOME/.lmstudio" || dc_dir "$HOME/.cache/kagglehub" ;;
    devops) dc_have kubectl || dc_have helm || dc_have vagrant || dc_have terraform || dc_have tofu || dc_dir "$HOME/.kube" || dc_dir "$HOME/.vagrant.d" || dc_dir "$HOME/Library/Caches/helm" ;;
    game) dc_dir "$HOME/Library/Caches/Unity" || dc_dir "$HOME/Library/Caches/Godot" || dc_dir "$HOME/Library/Unity" || dc_dir "$HOME/Library/Application Support/Godot" ;;
    *) return 1 ;;
  esac
}

# a git repo that holds Terraform, a Unity/Godot/Unreal project or notebooks counts as a developer project for the profile decision only
# (profile --tsv kind rows are unchanged: no new kind id, so no voice change)
dc2_marker_project() {
  local p="$1"
  compgen -G "$p/*.tf" >/dev/null || compgen -G "$p/*.ipynb" >/dev/null || compgen -G "$p/*.uproject" >/dev/null || [ -f "$p/project.godot" ] || [ -f "$p/ProjectSettings/ProjectVersion.txt" ]
}

dc2_ps_re() { local ps; ps="$(dc_ps)"; printf '%s\n' "$ps" | grep -qE "$1"; }   # ps captured first: the grep must not match its own command line
dc2_guard() {
  DWHY=""
  case "$1" in
    unity-upm-global-cache|unity-library|unity-temp)
      dc2_ps_re 'Unity\.app/Contents/MacOS/Unity([[:space:]]|$)' && { DWHY="a Unity Editor is running; close it first"; return 1; } ;;
    godot-cache-dir|godot-project-cache)
      dc2_ps_re 'Godot[^/]*\.app/Contents/MacOS/Godot' && { DWHY="a Godot editor is running; close it first"; return 1; } ;;
    unreal-intermediate)
      dc2_ps_re 'UnrealEditor' && { DWHY="an Unreal Editor is running; close it first"; return 1; } ;;
    terraform-plugin-cache|terraform-project-dirs)
      dc2_ps_re '(^|/)(terraform|tofu)([[:space:]]|$)' && { DWHY="terraform/tofu is running; wait for it to finish"; return 1; } ;;
  esac
  return 0
}

# $TF_PLUGIN_CACHE_DIR, only if it is a real directory under $HOME (not a symlink) whose top level looks like a provider cache
# (<registry host>/<namespace>/...: only directories whose names contain a dot). Prints the directory.
dc2_tf_dir() {
  local d="${TF_PLUGIN_CACHE_DIR:-}" rp h e
  [ -n "$d" ] && [ -d "$d" ] && [ ! -L "$d" ] || return 1
  rp="$(dc_rp "$d")"; h="$(dc_rp "$HOME")"
  case "$rp" in "$h"/?*) ;; *) return 1 ;; esac
  for e in "$d"/* "$d"/.[!.]*; do
    [ -e "$e" ] || continue
    [ -d "$e" ] && [ ! -L "$e" ] || return 1
    case "$(basename "$e")" in *.*) ;; *) return 1 ;; esac
  done
  printf '%s' "$d"
}

dc2_project_rows() {
  local p="$1" d
  protected "$p" && return 0
  find "$p" -maxdepth 6 \( -name node_modules -o -name .git -o -name .venv -o -name venv -o -name build -o -name Library \) -prune -o -type d -name .ipynb_checkpoints -print 2>/dev/null |
  while IFS= read -r d; do
    protected "$d" && continue
    emit "$(kb "$d")" ask-first jupyter-checkpoints "$d" "$(mtime "$d")" "rm-verified" \
      "only the last-save copy of each notebook is lost (recreated on the next Jupyter save); the .ipynb files are not touched. Source for this behaviour is secondary (kb/data-ml.md), so ask-first" "${p/#$HOME/~}"
  done
  find "$p" -maxdepth 4 \( -name node_modules -o -name .git -o -name build \) -prune -o -type d -name .terraform -print 2>/dev/null |
  while IFS= read -r d; do
    protected "$d" && continue
    compgen -G "$(dirname "$d")/*.tf" >/dev/null || continue
    git -C "$(dirname "$d")" check-ignore -q ".terraform" 2>/dev/null || continue   # only when git proves it ignored
    emit "$(kb "$d")" safe-regenerable terraform-project-dirs "$d" "$(mtime "$d")" "rm-verified (git-ignored)" \
      "providers and modules re-downloaded by the next terraform init (network); terraform.tfstate and .terraform.lock.hcl are not inside it" "${p/#$HOME/~}"
  done
}

dc2_game_markers() {   # prints marker files: ProjectVersion.txt, project.godot, *.uproject (pruned like find_projects, plus engine output dirs)
  local r
  for r in ${ROOTS:-$HOME}; do
    find "$r" -maxdepth 6 \( -name Library -o -name node_modules -o -name .gradle -o -name .pub-cache -o -name .Trash -o -name .android -o -name .cache \
      -o -name Applications -o -name .cargo -o -name .rustup -o -name .npm -o -name .claude -o -name build -o -name .dart_tool -o -name .git -o -name .godot \
      -o -name Intermediate -o -name Binaries -o -name Saved -o -name Assets -o -name Content \) -prune -o \
      \( -name project.godot -o -name '*.uproject' -o -name ProjectVersion.txt \) -type f -print 2>/dev/null
  done | sort -u
}

dc2_extra_rows() {
  local d f p b
  if d="$(dc2_tf_dir)"; then
    emit "$(kb "$d")" safe-regenerable terraform-plugin-cache "$d" "$(mtime "$d")" "rm-verified" \
      "providers re-downloaded on the next terraform init (network); Terraform does NOT create this directory, so mkdir it again afterwards" "-"
  fi
  dc2_game_markers | while IFS= read -r f; do
    p="$(dirname "$f")"; b="$(basename "$f")"
    case "$b" in
      ProjectVersion.txt) [ "$(basename "$p")" = ProjectSettings ] || continue; p="$(dirname "$p")"
        protected "$p" && continue
        [ -d "$p/Library" ] && emit "$(kb "$p/Library")" ask-first unity-library "$p/Library" "$(mtime "$p/Library")" "rm-verified" \
          "Unity reimports every asset and recompiles scripts on next open (minutes to hours on a big project); close the Editor first; Assets/ and ProjectSettings/ are not touched" "${p/#$HOME/~}"
        [ -d "$p/Temp" ] && emit "$(kb "$p/Temp")" ask-first unity-temp "$p/Temp" "$(mtime "$p/Temp")" "rm-verified" \
          "scratch folder recreated by the Editor on next launch; close the Editor first (a stale Temp/UnityLockfile after a crash is the usual reason to delete it)" "${p/#$HOME/~}" ;;
      project.godot) protected "$p" && continue
        [ -d "$p/.godot" ] && emit "$(kb "$p/.godot")" ask-first godot-project-cache "$p/.godot" "$(mtime "$p/.godot")" "rm-verified" \
          "Godot reimports every asset on next open (slow on big projects); deletion safety rests on forum reports only (UID or tileset confusion possible), so back up first; close the editor" "${p/#$HOME/~}" ;;
      *.uproject) protected "$p" && continue
        [ -d "$p/Intermediate" ] && emit "$(kb "$p/Intermediate")" ask-first unreal-intermediate "$p/Intermediate" "$(mtime "$p/Intermediate")" "rm-verified" \
          "rebuilt on next compile and shader build (tens of minutes to hours); Epic documents Intermediate as deletable; Binaries and Saved are NOT offered; close the editor" "${p/#$HOME/~}" ;;
    esac
  done
}

# apply side: recognise the same paths again from their markers. Sets CLS REM CATID WHY.
dc2_classify() {
  local t="$1" b p top d
  b="$(basename "$t")"; p="$(dirname "$t")"
  [ -d "$t" ] || return 1
  case "$b" in
    Library|Temp) [ -f "$p/ProjectSettings/ProjectVersion.txt" ] || return 1
      [ "$b" = Library ] && CATID=unity-library || CATID=unity-temp
      CLS=ask-first; REM="rm-verified"; WHY="catalog:$CATID (Unity project ${p/#$HOME/~}, ProjectVersion.txt present)"; return 0 ;;
    .godot) [ -f "$p/project.godot" ] || return 1
      CLS=ask-first; REM="rm-verified"; CATID=godot-project-cache; WHY="catalog:$CATID (project.godot present)"; return 0 ;;
    Intermediate) compgen -G "$p/*.uproject" >/dev/null || return 1
      CLS=ask-first; REM="rm-verified"; CATID=unreal-intermediate; WHY="catalog:$CATID (*.uproject present)"; return 0 ;;
    .ipynb_checkpoints) git -C "$p" rev-parse --show-toplevel >/dev/null 2>&1 || return 1
      CLS=ask-first; REM="rm-verified"; CATID=jupyter-checkpoints; WHY="catalog:$CATID (inside a git project)"; return 0 ;;
    .terraform) compgen -G "$p/*.tf" >/dev/null || return 1
      top="$(git -C "$p" rev-parse --show-toplevel 2>/dev/null)" || { WHY=".terraform outside a git repo"; return 2; }
      git -C "$p" check-ignore -q ".terraform" 2>/dev/null || { WHY="NOT git-ignored in ${top/#$HOME/~}"; return 2; }
      CLS=safe-regenerable; REM="rm-verified"; CATID=terraform-project-dirs; WHY="catalog:$CATID (git-ignored in ${top/#$HOME/~})"; return 0 ;;
  esac
  if [ -n "${TF_PLUGIN_CACHE_DIR:-}" ] && [ "$(dc_rp "$t")" = "$(dc_rp "$TF_PLUGIN_CACHE_DIR")" ]; then
    dc2_tf_dir >/dev/null || { WHY="TF_PLUGIN_CACHE_DIR does not look like a provider cache (outside \$HOME, symlink, or entries that are not registry hosts); refusing"; return 2; }
    CLS=safe-regenerable; REM="rm-verified"; CATID=terraform-plugin-cache; WHY="catalog:$CATID (TF_PLUGIN_CACHE_DIR)"; return 0
  fi
  return 1
}
