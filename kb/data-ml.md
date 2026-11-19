# Data / ML developer

Cross-reference: pip, uv and conda package caches and conda environments are documented in `python.md` (`pip-cache`, `uv-cache`, `conda-pkgs`) and are not repeated here. CUDA wheels and CUDA toolkits do not apply on macOS (no NVIDIA support); Apple-silicon ML uses MLX or PyTorch MPS, whose wheels sit in the pip cache.

## Entries

### hf-hub-cache
- what: Hugging Face hub cache, one folder per downloaded model, dataset or space (blobs, snapshots, refs); shared by transformers, diffusers, sentence-transformers, mlx-lm, llama.cpp and others
- catalog-id: hf-hub-cache
- paths: ~/.cache/huggingface/hub (default; $HF_HUB_CACHE, else $HF_HOME/hub, else $XDG_CACHE_HOME/huggingface/hub)
- size: 1.6 G (measured here, ~/.cache/huggingface/hub 1668260 KB; mlx-community whisper-large-v3-turbo 1576172 KB, all-MiniLM-L6-v2 89468 KB, faster-whisper-small 2616 KB); real caches reach tens of G (unverified)
- class: ask-first
- removal: catalog row is rm-verified of the WHOLE ~/.cache/huggingface/hub (apply re-verifies path, symlink, running process, open files); per model use `hf cache ls` then `hf cache rm model/<org>/<name>` (add --dry-run first); `hf cache prune` removes unreferenced revisions and .incomplete files; older CLI name `huggingface-cli delete-cache` (unverified, not on the fetched page)
- regen: weights re-download from the hub on next use; costly in time and bandwidth, impossible offline or if the repo was deleted or gated; never rm individual blobs by hand because snapshots symlink to them
- growth: never auto-pruned; a new revision keeps the old blobs; large cached models dominate. Suggested budget 20 G (suggested)
- source: measured on this host 2026-11-18; reported online, https://huggingface.co/docs/huggingface_hub/guides/manage-cache and https://huggingface.co/docs/huggingface_hub/package_reference/environment_variables fetched 2026-11-18

### hf-xet-cache
- what: Hugging Face xet shard cache and upload staging, plus the assets cache used by downstream libraries
- catalog-id: hf-xet-cache
- paths: ~/.cache/huggingface/xet ($HF_XET_CACHE); (the assets cache ~/.cache/huggingface/assets is NOT a catalog row: no documented command)
- size: 87 M (measured here, ~/.cache/huggingface/xet 88792 KB); xet shard-cache soft limit 16 GB (reported online, https://huggingface.co/docs/huggingface_hub/package_reference/environment_variables)
- class: safe-regenerable
- removal: rm-verified of ~/.cache/huggingface/xet (the docs say removing the xet dir entirely reclaims the space); assets has no documented command (unverified)
- regen: shards re-downloaded on the next upload; an interrupted upload loses its resume state; downloaded model files are not stored here
- growth: shards expire 3-4 weeks after download and are deleted a week later per the docs; suggested budget 1 G (suggested)
- source: measured on this host 2026-11-18; reported online, https://huggingface.co/docs/huggingface_hub/guides/manage-cache fetched 2026-11-18

### hf-datasets-cache
- what: Hugging Face datasets library Arrow-converted dataset cache (separate from raw files in the hub cache)
- catalog-id: none
- paths: ~/.cache/huggingface/datasets ($HF_DATASETS_CACHE, or $HF_HOME/datasets)
- size: not present on this host; commonly several G (unverified)
- class: ask-first
- removal: Dataset.cleanup_cache_files() from Python; otherwise rm-verified of a single dataset folder; raw sources are removed with `hf cache rm dataset/<name>`
- regen: dataset re-prepared from the hub and re-converted to Arrow; slow for large sets; datasets you built with save_to_disk are NOT in this cache and are never to be removed
- growth: grows per dataset and per .map() transform fingerprint; transform caches accumulate. Suggested budget 10 G (suggested)
- source: reported online, https://huggingface.co/docs/datasets/cache fetched 2026-11-18

### torch-hub-cache
- what: PyTorch hub cache and pretrained checkpoints downloaded by torch.hub and torchvision/torchaudio
- catalog-id: torch-hub-cache
- paths: ~/.cache/torch/hub; checkpoints in ~/.cache/torch/hub/checkpoints (precedence: hub.set_dir, $TORCH_HOME/hub, $XDG_CACHE_HOME/torch/hub, ~/.cache/torch/hub)
- size: not present on this host; tens of M to several G (unverified)
- class: ask-first
- removal: catalog row is rm-verified of ~/.cache/torch/hub (no PyTorch command exists; ask-first because a locally saved .pt may sit in it)
- regen: checkpoints re-download from their URL on next load; a locally trained .pt you saved into this folder cannot be regenerated, so look at filenames first
- growth: one file per pretrained model; never pruned. Suggested budget 5 G (suggested)
- source: reported online, https://docs.pytorch.org/docs/2.15/hub.html fetched 2026-11-18

### keras-datasets-models
- what: Keras get_file cache for downloaded datasets (MNIST, CIFAR) and pretrained application weights
- catalog-id: none
- paths: ~/.keras (or $KERAS_HOME); datasets/ and models/ underneath
- size: not present on this host; (unverified)
- class: ask-first
- removal: report-only; rm-verified of ~/.keras/datasets or ~/.keras/models; keep ~/.keras/keras.json (config) and anything you saved yourself
- regen: re-download on next call; model.save() output written here by a project is not regenerable
- growth: per distinct dataset/weights file. Suggested budget 3 G (suggested)
- source: reported online, https://www.tensorflow.org/api_docs/python/tf/keras/utils/get_file fetched 2026-11-18 (cache_dir ~/.keras or $KERAS_HOME, cache_subdir datasets); models/ and keras.json are (unverified)

### tfds-data
- what: TensorFlow Datasets downloaded and prepared tfrecord data
- catalog-id: none
- paths: ~/tensorflow_datasets (data_dir default); downloads in ~/tensorflow_datasets/downloads (and ~/tensorflow_datasets/download per one page note)
- size: not present on this host; ImageNet-class sets reach hundreds of G (unverified)
- class: ask-first
- removal: report-only; rm-verified of one dataset folder; manual_dir (downloads/manual) holds files you fetched by hand and must stay
- regen: `tfds build <name>` or tfds.load re-downloads; some datasets need manual files and credentials
- growth: per dataset version. Suggested budget 20 G (suggested)
- source: reported online, https://www.tensorflow.org/datasets/overview fetched 2026-11-18

### ollama-models
- what: Ollama model store (manifests and blobs of pulled models and your own `ollama create` models)
- catalog-id: ollama-models
- paths: ~/.ollama/models (macOS; $OLLAMA_MODELS overrides); Linux /usr/share/ollama/.ollama/models
- size: not present on this host; 2 to 40 G per model (unverified)
- class: ask-first
- removal: catalog row is REPORT-ONLY (apply refuses): `ollama ls` to list, `ollama rm <model>` per model by hand (never rm blobs: they are shared between models)
- regen: `ollama pull <model>` re-downloads; models made with `ollama create` from your own Modelfile or fine-tune are only re-creatable if the source files exist, so class those never without a source
- growth: one blob set per pulled tag, old tags stay until removed. Suggested budget 30 G (suggested)
- source: reported online, https://docs.ollama.com/faq (macOS path, OLLAMA_MODELS) and https://docs.ollama.com/cli (ls, rm) fetched 2026-11-18

### lmstudio-models
- what: LM Studio downloaded GGUF and MLX models in publisher/model folders
- catalog-id: lmstudio-models
- paths: ~/.lmstudio/models (current default); older builds ~/.cache/lm-studio/models and ~/Library/Application Support/LM Studio/models
- size: not present on this host; 2 to 40 G per model (unverified)
- class: ask-first
- removal: catalog row is REPORT-ONLY (apply refuses): delete from LM Studio My Models tab by hand; deletion procedure is not on the fetched official page (unverified)
- regen: re-download from Hugging Face; models you imported with `lms import` or side-loaded may have no other copy
- growth: per downloaded model and quantisation. Suggested budget 30 G (suggested)
- source: reported online, https://lmstudio.ai/docs/app/advanced/import-model (layout ~/.lmstudio/models/publisher/model, via search result 2026-11-18) and https://lmstudio.ai/docs/app/basics/download-model fetched 2026-11-18 (models directory changeable in My Models; default path not stated there)

### llamacpp-gguf-cache
- what: GGUF files fetched by llama.cpp (llama-cli/llama-server -hf or --model-url), plus any hand-downloaded .gguf
- catalog-id: none
- paths: $LLAMA_CACHE; recent builds reuse ~/.cache/huggingface/hub (see hf-hub-cache); older builds ~/Library/Caches/llama.cpp; RPC cache ~/.cache/llama.cpp/rpc; hand-placed .gguf anywhere (e.g. ~/models)
- size: not present on this host; (unverified)
- class: ask-first
- removal: `llama-cli --cache-list` shows cached models; removal is `hf cache rm` when in the HF cache, else rm-verified of the file; hand-placed files are the user's choice
- regen: re-download via -hf; self-converted or self-quantised GGUF files are costly to rebuild and need the original weights
- growth: one file per model and quant. Suggested budget 30 G (suggested)
- source: reported online, https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md fetched 2026-11-18 (-hf, --cache-list, --offline; LLAMA_CACHE and cache path NOT on that page); path precedence from a web search 2026-11-18 (secondary blog and a 2024 llama.cpp commit), so (unverified) against current source

### jupyter-data-and-kernels
- what: Jupyter user data dir (kernelspecs, nbextensions, runtime connection files) and config
- catalog-id: none
- paths: ~/Library/Application Support/Jupyter (data, kernels/, runtime/); ~/.jupyter (config); overrides $JUPYTER_DATA_DIR, $JUPYTER_CONFIG_DIR, $JUPYTER_RUNTIME_DIR
- size: not present on this host; usually under 50 M (unverified)
- class: ask-first
- removal: `jupyter kernelspec list` then `jupyter kernelspec uninstall <name>` (command not on the fetched page, unverified); runtime/ files of dead kernels are rm-verified
- regen: kernelspecs come back with `python -m ipykernel install --user`; ~/.jupyter holds hand-written config and password hashes that are not regenerable
- growth: one kernelspec per installed env; stale runtime files accumulate. Suggested budget 100 M (suggested)
- source: reported online, https://docs.jupyter.org/en/latest/use/jupyter-directories.html fetched 2026-11-18 (macOS data, config, runtime paths; `jupyter --paths`)

### jupyter-checkpoints
- what: .ipynb_checkpoints folders holding the last manual-save copy of each notebook, created next to the notebook
- catalog-id: none
- paths: <notebook dir>/.ipynb_checkpoints (found by find under project dirs)
- size: small per notebook, but copies embed outputs and images; (unverified)
- class: ask-first
- removal: rm-verified of the .ipynb_checkpoints directory; never touch the .ipynb itself. Engine finds these in code per discovered git project and offers them ask-first (the only sources are secondary, so not safe-regenerable)
- regen: recreated on the next Jupyter save; you only lose the revert-to-checkpoint copy
- growth: one copy per notebook. No budget; clean when found (suggested)
- source: reported online, search 2026-11-18 returned only secondary sources (julius.ai, fast.ai forum, jupyter-server source listing); the official jupyter-server configuration page fetched 2026-11-18 did not cover it, so (unverified)

### mlflow-local-runs
- what: MLflow local file tracking store of experiments, runs, metrics and artifacts
- catalog-id: none
- paths: ./mlruns and ./mlartifacts inside a project dir (file backend, `--backend-store-uri ./mlruns`); also mlflow.db for SQLite
- size: not present on this host; (unverified)
- class: never
- removal: report-only; for runs already marked deleted `mlflow gc` permanently removes their metadata and artifacts, only on the user's say-so
- regen: not regenerable: these are experiment results, parameters and logged models from your own training runs
- growth: one directory per run; artifacts can be large. Archive or budget per project (suggested)
- source: reported online, https://mlflow.org/docs/latest/self-hosting/architecture/backend-store/ fetched 2026-11-18 (./mlruns file backend, now legacy, SQLite is default; `mlflow gc` permanently removes deleted runs); ./mlartifacts is NOT confirmed there (unverified)

### wandb-local-runs
- what: Weights & Biases per-project local run directories, offline runs and logs
- catalog-id: none
- paths: ./wandb/run-YYYYMMDD_HHMMSS-<id> and ./wandb/offline-run-* in each project; $WANDB_DIR overrides; ./artifacts ($WANDB_ARTIFACT_DIR)
- size: not present on this host; (unverified)
- class: ask-first
- removal: `wandb sync` first for offline runs; `wandb clean` deletes local data for runs that were synced (per docs); rm-verified of wandb/ only after confirming runs are uploaded
- regen: synced runs live on the W&B server; offline runs not yet synced are lost for good
- growth: one dir per run; the user decides. Suggested: prune synced runs older than 30 d (suggested)
- source: reported online, https://docs.coreweave.com/models/ref/cli/wandb-sync and https://docs.coreweave.com/models/track/environment-variables fetched 2026-11-18 (docs.wandb.ai redirects there)

### wandb-cache
- what: W&B downloaded artifact cache and platform data dir
- catalog-id: wandb-cache
- paths: ~/.cache/wandb ($WANDB_CACHE_DIR); data dir from platformdirs user_data_dir ($WANDB_DATA_DIR), on macOS likely ~/Library/Application Support/wandb (unverified)
- size: not present on this host; (unverified)
- class: safe-regenerable
- removal: catalog row is rm-verified of ~/.cache/wandb (the documented tool command `wandb artifact cache cleanup <size>` needs a size argument and is run by hand when only part should go; drops least recently used first)
- regen: artifacts re-download from W&B; needs network and login
- growth: per downloaded artifact version. Suggested budget 5 G (suggested)
- source: reported online, https://docs.coreweave.com/models/ref/cli/wandb-artifact/wandb-artifact-cache/wandb-artifact-cache-cleanup and https://docs.coreweave.com/models/track/environment-variables fetched 2026-11-18

### dvc-cache
- what: DVC content-addressed data cache holding every version of tracked datasets and models, plus the site cache
- catalog-id: none
- paths: <repo>/.dvc/cache; site cache /Library/Caches/dvc (macOS, index/hashes/links, not the data cache); shared caches via configured cache dir
- size: not present on this host; as large as the tracked data times its versions (unverified)
- class: never
- removal: report-only; `dvc gc -w --dry` previews, `dvc gc` needs a scope flag (-w, -a, -T, -A) and deletes cache objects not referenced; never `-c` without explicit consent (deletes remote data irreversibly)
- regen: only recoverable by `dvc fetch`/`dvc pull` if the data was pushed to a remote; with no remote the cache is the only copy
- growth: one object per file version; gc trims. Check `dvc remote list` before any action (suggested)
- source: reported online, https://doc.dvc.org/command-reference/gc and https://doc.dvc.org/user-guide/project-structure/internal-files fetched 2026-11-18 (the dvc.org/doc URLs redirect there)

### kaggle-cache
- what: kagglehub downloaded datasets and models, and Kaggle API credentials
- catalog-id: kaggle-cache
- paths: ~/.cache/kagglehub ($KAGGLEHUB_CACHE); credentials ~/.kaggle/kaggle.json and ~/.kaggle/access_token
- size: not present on this host; (unverified)
- class: ask-first
- removal: catalog row is REPORT-ONLY (apply refuses): no clearing command is documented; delete ~/.cache/kagglehub subfolders by hand; NEVER remove ~/.kaggle credentials
- regen: re-download via kagglehub with force_download; needs a Kaggle login and accepted competition rules
- growth: per dataset or model version. Suggested budget 10 G (suggested)
- source: reported online, https://github.com/Kaggle/kagglehub fetched 2026-11-18

### nltk-data
- what: NLTK corpora and models downloaded with nltk.download
- catalog-id: none
- paths: ~/nltk_data (typical user location, unverified); central /usr/local/share/nltk_data (macOS), /usr/share/nltk_data; $NLTK_DATA overrides
- size: not present on this host; full set is several G (unverified)
- class: safe-regenerable
- removal: rm-verified of the nltk_data directory or one subfolder (no removal command documented)
- regen: `python -m nltk.downloader <id>` re-downloads; needs network
- growth: only what was downloaded; `all` is the large case. Suggested budget 3 G (suggested)
- source: reported online, https://www.nltk.org/data.html fetched 2026-11-18 (central paths, NLTK_DATA, downloader; the ~/nltk_data default is not on that page)

### spacy-models
- what: spaCy pipelines (en_core_web_*), installed as pip packages, not in a data folder
- catalog-id: none
- paths: <env>/lib/pythonX/site-packages/en_core_web_* (inside the venv or conda env that ran `spacy download`)
- size: not present on this host; (unverified)
- class: safe-regenerable
- removal: `pip uninstall <pipeline-package>` (not stated on the fetched page, standard pip, unverified); goes away with its venv
- regen: `python -m spacy download <name>` re-installs
- growth: per env and per pipeline; duplicated across venvs. No budget (suggested)
- source: reported online, https://spacy.io/usage/models fetched 2026-11-18 (installed via pip into site-packages)

### mlx-models-cache
- what: Apple MLX / mlx-lm model downloads; they land in the Hugging Face hub cache, plus converted output folders
- catalog-id: none
- paths: ~/.cache/huggingface/hub/models--mlx-community--* (see hf-hub-cache); `mlx_lm.convert` output ./mlx_model; prompt-cache .safetensors files
- size: 1.5 G for mlx-community whisper-large-v3-turbo (measured here, 1576172 KB); others (unverified)
- class: ask-first
- removal: `hf cache rm model/mlx-community/<name>`; converted ./mlx_model dirs: ask-first, they may be your own quantisations
- regen: downloads re-fetch; your own converted or fine-tuned (adapter) output is not recoverable without the base weights and your data
- growth: one folder per model and quantisation. Part of the hf-hub-cache budget (suggested)
- source: measured on this host 2026-11-18; reported online, https://github.com/ml-explore/mlx-lm fetched 2026-11-18 (downloads from the HF Hub and default mlx_model output; the page does not state the cache location, which follows from hf-hub-cache)

## Developer habits
- Pull many model variants and quantisations to try them, never remove old ones, and the Hugging Face, Ollama and LM Studio stores quietly reach tens of G.
- Run the same weights through several tools (HF cache, LM Studio, llama.cpp, Ollama), so the same model is on disk two or three times with no deduplication across tools.
- Leave per-project experiment output (mlruns, wandb, checkpoints) beside the code; those are the work product, not cache.
- Create one conda or venv per project, each with its own torch or tensorflow wheels (see python.md).

## Signals
- Dirs: ~/.cache/huggingface, ~/.cache/torch, ~/.keras, ~/.ollama, ~/.lmstudio, ~/.cache/kagglehub, ~/.kaggle, ~/nltk_data, ~/tensorflow_datasets, ~/Library/Application Support/Jupyter, ~/.jupyter.
- Project files: mlruns/, wandb/, .dvc/, dvc.yaml, .ipynb_checkpoints/, *.ipynb, *.gguf, *.safetensors, environment.yml, requirements.txt naming torch, transformers, mlx.
- Commands on PATH: ollama, hf, huggingface-cli, jupyter, dvc, wandb, mlflow, conda, mamba, llama-cli, lms.

## Not covered / open questions
- Hugging Face `huggingface-cli delete-cache` (old name) was not confirmed on the fetched pages; only `hf cache rm` and `hf cache prune` were.
- Ollama on macOS may keep a separate app data dir (logs, ~/.ollama/history); not checked.
- LM Studio delete procedure and the default path on the official page; the path came from a search summary.
- The llama.cpp cache location in current source, the `LLAMA_CACHE` precedence, and MLX cache behaviour beyond the HF cache.
- Jupyter checkpoint behaviour on the official side, `jupyter kernelspec uninstall`, `~/nltk_data` default, `pip uninstall` for spaCy, mlflow ./mlartifacts, the W&B data dir on macOS.
- Diffusers, ComfyUI, Stable Diffusion UIs, whisper.cpp, Core ML and MPS caches, and Docker-based model volumes are not covered.
- Apple-specific CUDA caches: no CUDA on macOS, so no entries.
