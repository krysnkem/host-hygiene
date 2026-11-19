# Python developer

## Entries

### pip-cache
- what: pip's HTTP and wheel build cache
- catalog-id: pip-cache
- paths: ~/Library/Caches/pip (macOS); ~/.cache/pip (Linux)
- size: 199 M (measured here, ~/Library/Caches/pip 203656 KB); large on heavy ML users (unverified)
- class: safe-regenerable
- removal: pip cache purge
- regen: wheels and indexes re-downloaded or rebuilt on next install; needs network
- growth: grows with every distinct package version installed; never pruned. Suggested budget 2 G (suggested)
- source: measured on this host 2026-11-17; reported online, https://pip.pypa.io/en/stable/topics/caching/ (macOS ~/Library/Caches/pip, XDG_CACHE_HOME respected) and https://pip.pypa.io/en/stable/cli/pip_cache/ (purge), fetched 2026-11-17

### uv-cache
- what: uv's package and built-wheel cache (hard-linked into venvs)
- catalog-id: uv-cache
- paths: ~/.cache/uv (uv documents this default on macOS too); also `uv cache dir`
- size: not present on this host; typically hundreds of M to several G (unverified)
- class: safe-regenerable
- removal: uv cache clean (all entries; `uv cache clean <pkg>` for one package); uv cache prune removes unused entries and centralized project environments
- regen: re-download on next sync; uv falls back to copying when cache and venv are on different filesystems, and the docs do not say venvs break after a clean
- growth: grows per package version; `uv cache prune` trims. Suggested budget 5 G (suggested)
- source: reported online, https://docs.astral.sh/uv/concepts/cache/ fetched 2026-11-17 (default $XDG_CACHE_HOME/uv or ~/.cache/uv on Unix; clean and prune confirmed; the page states no size)

### poetry-cache
- what: Poetry download cache and its default virtualenvs
- catalog-id: none
- paths: ~/Library/Caches/pypoetry (cache, virtualenvs/); ~/.cache/pypoetry on Linux
- size: not present on this host; (unverified)
- class: ask-first
- removal: poetry cache clear --all <repo>; poetry env remove <python> for a venv
- regen: caches re-download; removed venvs are rebuilt by `poetry install` only if poetry.lock or pyproject.toml exists
- growth: one venv per project plus downloads. Suggested budget 3 G (suggested)
- source: reported online, https://python-poetry.org/docs/configuration/ fetched 2026-11-17 (cache-dir macOS ~/Library/Caches/pypoetry, Linux $XDG_CACHE_HOME/pypoetry; virtualenvs.path defaults to {cache-dir}/virtualenvs; `poetry cache clear` and `poetry env remove` commands not re-checked on that page)

### pipenv-virtualenvs
- what: Pipenv's central virtualenvs, one per project, plus its cache
- catalog-id: none
- paths: ~/.local/share/virtualenvs; ~/Library/Caches/pipenv
- size: not present on this host; (unverified)
- class: ask-first
- removal: pipenv --rm (inside the project); pipenv lock --clear for cache
- regen: rebuilt by `pipenv install` only if Pipfile/Pipfile.lock exists; otherwise the env may be the only record of its packages
- growth: one env per project, never auto-removed when the project is deleted (orphans). Suggested: delete orphans (suggested)
- source: reported online, https://pipenv.pypa.io/en/latest/virtualenv.html fetched 2026-11-17 (virtualenvs in ~/.local/share/virtualenvs on Linux and macOS; `pipenv --rm` keeps Pipfile and Pipfile.lock); the ~/Library/Caches/pipenv path and `pipenv lock --clear` are (unverified)

### conda-pkgs
- what: conda/mamba package tarball and extracted-package cache, plus named environments
- catalog-id: none
- paths: ~/miniconda3/pkgs, ~/anaconda3/pkgs, ~/miniforge3/pkgs; envs in <root>/envs and ~/.conda/envs
- size: not present on this host; commonly several G to tens of G (unverified)
- class: ask-first
- removal: conda clean -a (pkgs and tarballs); conda env remove -n <name> for envs
- regen: packages re-download; an env with no exported environment.yml cannot be reproduced exactly
- growth: every env creation adds extracted packages; `conda clean -a` reclaims unreferenced ones. Suggested budget 10 G (suggested)
- source: reported online, https://docs.conda.io/projects/conda/en/stable/commands/clean.html and https://docs.conda.io/projects/conda/en/stable/user-guide/tasks/manage-environments.html fetched 2026-11-17 (`conda clean --all` removes index cache, unused packages, tarballs, temp and log files; `conda env remove --name`; envs live in <install>/envs); install-root pkgs paths and ~/.conda/envs are (unverified)

### pyenv-versions
- what: Python interpreters built or installed by pyenv
- catalog-id: pyenv-versions
- paths: ~/.pyenv/versions/*
- size: not present on this host; roughly 100-400 M per version (unverified)
- class: ask-first
- removal: pyenv uninstall -f <version> (catalog; -f skips the prompt, confirmed https://github.com/pyenv/pyenv/blob/master/COMMANDS.md 2026-11-17; apply refuses a version pinned by a project or the global file)
- regen: reinstall compiles from source, minutes; venvs created from that version break
- growth: one dir per installed version; never pruned. Suggested: keep versions pinned by .python-version files (suggested)
- source: reported online, https://github.com/pyenv/pyenv fetched 2026-11-17 (versions in $(pyenv root)/versions, default ~/.pyenv/versions; `pyenv uninstall <version>` needs the full version name); size unverified

### python-venv
- what: per-project virtual environment (.venv, venv, env)
- catalog-id: none
- paths: <project>/.venv, <project>/venv
- size: 144 M for ~/projects/report/.venv (measured here); ML projects can be GBs (unverified)
- class: ask-first
- removal: rm-verified after confirming the dir is git-ignored
- regen: safe-regenerable ONLY if requirements.txt, uv.lock, poetry.lock or pyproject.toml exists; otherwise the venv is the only record of versions, keep it
- growth: one per project, left behind by abandoned projects. Suggested budget 500 M per project (suggested)
- source: measured on this host 2026-11-17; reported online, https://docs.python.org/3/library/venv.html fetched 2026-11-17 (venv is disposable, recreate rather than move)

### python-bytecode-and-tool-caches
- what: __pycache__, .pytest_cache, .mypy_cache, .ruff_cache, .tox, .nox, .ipynb_checkpoints inside projects
- catalog-id: none
- paths: <project>/__pycache__, .pytest_cache, .mypy_cache, .ruff_cache, .tox, .nox, .ipynb_checkpoints
- size: small, KB to tens of M each; .mypy_cache and .tox can reach hundreds of M (unverified)
- class: safe-regenerable
- removal: rm-verified (git-ignored dirs only); tools: `ruff clean`, `tox -e <env> -r` to recreate
- regen: rebuilt on next import, test, lint or type-check run; .tox/.nox envs need network to reinstall deps. .ipynb_checkpoints may hold an unsaved-notebook autosave: ask-first for that one
- growth: grows with project size and number of tool runs. Suggested: sweep when the project is idle (suggested)
- source: (unverified); presence of __pycache__ measured on this host (~/magic/learning-assistant/scripts)

## Developer habits
Many per-project venvs, conda envs per experiment, several pyenv interpreters, notebooks, ML wheels that are large.

## Signals
pyproject.toml, requirements.txt, Pipfile, poetry.lock, uv.lock, environment.yml, .python-version, ~/.pyenv, ~/miniconda3, `python3`/`pip` on PATH.

## Not covered / open questions
- Homebrew Python is system-managed (brew); Hugging Face / torch model caches (~/.cache/huggingface, ~/.cache/torch) are large but not researched here.
- Exact macOS paths for uv and pipenv were not verified on a host that has them; the pipenv cache dir and `pipenv lock --clear` were not confirmed by the pipenv docs fetched; conda's pkgs dir paths under miniconda/anaconda/miniforge and ~/.conda/envs, .tox/.mypy_cache/.ruff_cache sizes and the tool-cache entry were not researched.
