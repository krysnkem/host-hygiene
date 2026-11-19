# DevOps: containers, clusters, IaC and cloud CLIs

One file per developer type. Three fixed sections after the entries, in this order.
Research date 2026-11-18. Official docs fetched: docs.docker.com, developer.hashicorp.com, helm.sh, kubernetes.io, minikube.sigs.k8s.io, docs.brew.sh, pulumi.com, docs.ansible.com, learn.microsoft.com, docs.cloud.google.com, docs.podman.io, lima-vm.io, k3d.io, kind.sigs.k8s.io, virtualbox.org. Sizes marked `measured here` were read with du -sk / `docker system df` on this Mac (read-only).

## Entries

### docker-data
- what: Docker Desktop's whole data container on macOS: the VM disk image plus settings; images, containers, volumes and build cache all live inside the Docker.raw file
- catalog-id: docker-data
- paths: ~/Library/Containers/com.docker.docker
- size: 8211764 KB (~7.8 GB) for the container dir, of which Docker.raw is 8125232 KB (measured here); Docker.raw is a sparse file that grows up to a configured maximum (reported online, https://docs.docker.com/desktop/troubleshoot-and-support/faqs/macfaqs/)
- class: ask-first
- removal: `docker system prune` (stopped containers, unused networks, dangling images, build cache; volumes NOT included, reported online, https://docs.docker.com/engine/manage-resources/pruning/); never rm the Docker.raw file by hand
- regen: pruned images are re-pulled (network) and build cache rebuilt (slow once); deleting Docker.raw or lowering the max-size slider deletes ALL containers, images and volumes (reported online, https://docs.docker.com/desktop/troubleshoot-and-support/faqs/macfaqs/)
- growth: Deleting files inside a container does not free host space, only deleting images does; host space returns within minutes, or on demand via `docker run --privileged --pid=host docker/desktop-reclaim-space` (reported online, same macfaqs page); size on disk is `ls -klsh Docker.raw`, other tools show the maximum; budget 10 GB (suggested)
- source: https://docs.docker.com/desktop/troubleshoot-and-support/faqs/macfaqs/ fetched 2026-11-18; sizes measured on this host 2026-11-18

### docker-images
- what: Docker images stored in the Desktop VM disk; unused ones are the reclaimable part
- catalog-id: none
- paths: inside Docker.raw (no host path); inspect with `docker system df` and `docker system df -v`
- size: Images 10 total, 5 active, 2.512 GB, 1.203 GB reclaimable (measured here, `docker system df` 2026-11-18)
- class: ask-first
- removal: `docker image prune` removes dangling images; `docker image prune -a` removes all images not used by a container (reported online, https://docs.docker.com/engine/manage-resources/pruning/); ask first because 3 containers are running here
- regen: re-pull from the registry (network, minutes); locally built images need a rebuild
- growth: every pull and build adds layers; old tags linger; budget under 5 GB (suggested)
- source: https://docs.docker.com/engine/manage-resources/pruning/ fetched 2026-11-18; https://docs.docker.com/reference/cli/docker/system/df/ fetched 2026-11-18

### docker-build-cache
- what: BuildKit build cache records, regenerable layer cache of past `docker build` runs
- catalog-id: none
- paths: inside Docker.raw (no host path)
- size: 21 records, 2.325 GB, all reclaimable, 0 active (measured here, `docker system df` 2026-11-18)
- class: safe-regenerable
- removal: `docker buildx prune` (alias `docker builder prune`); `--filter "until=24h"` keeps recent records; `--all` also removes internal helper images (reported online, https://docs.docker.com/reference/cli/docker/buildx/prune/)
- regen: next build is slower once, no data lost
- growth: grows with every build and every changed layer; docs offer `--max-used-space` to cap it; budget 2 GB (suggested)
- source: https://docs.docker.com/reference/cli/docker/buildx/prune/ fetched 2026-11-18

### docker-volumes
- what: Docker named and anonymous volumes, which hold container data such as databases and uploads
- catalog-id: none
- paths: inside Docker.raw (no host path); list with `docker volume ls`
- size: 18 volumes, 7 active, 1.368 GB, 1.122 GB shown reclaimable (measured here); names include app_postgres_data, app_redis_data, app_uploads_data, cert_learning_partner_* (measured here); the "reclaimable" figure is NOT permission to delete
- class: never
- removal: none by the tool without user choice; `docker volume prune` removes unused anonymous volumes, `docker volume prune --all` also removes unused named volumes, and `docker system prune --volumes` adds anonymous ones (reported online, https://docs.docker.com/engine/manage-resources/pruning/). DATA LOSS: deleted volume contents cannot be recovered. Never unless the user picks a specific volume
- regen: none; data is lost unless backed up; only caches such as uat-gocache and uat-gomod are rebuildable (inferred from names, (unverified))
- growth: grows with the data the containers write; no automatic cleanup
- source: https://docs.docker.com/engine/manage-resources/pruning/ fetched 2026-11-18; sizes measured on this host 2026-11-18

### colima-lima-vms
- what: Colima and Lima Linux VMs that run containers on macOS, each with its own disk image
- catalog-id: none
- paths: ~/.colima, ~/.lima, ~/Library/Caches/lima ((unverified) path for cache)
- size: absent here (measured here, ~/.colima and ~/.lima not present); Colima's default VM is 2 CPUs, 2 GiB memory, 100 GiB disk (reported online, https://github.com/abiosoft/colima)
- class: ask-first
- removal: `colima delete` and `limactl delete <instance>` (command names (unverified), pages did not describe them); `limactl prune` clears the download cache (reported online, https://lima-vm.io/docs/faq/)
- regen: deleting an instance destroys the containers, images and volumes inside it; the VM is recreated empty
- growth: disk image grows with container data up to the configured size; Lima instance files sit under $HOME/.lima/<INSTANCE> (reported online, https://lima-vm.io/docs/faq/)
- source: https://github.com/abiosoft/colima and https://lima-vm.io/docs/faq/ fetched 2026-11-18

### orbstack-podman-machines
- what: OrbStack data and Podman machine VM images, alternative container runtimes on macOS
- catalog-id: none
- paths: ~/.orbstack ((unverified), OrbStack docs page returned 404), ~/.local/share/containers/podman/machine/ (QEMU example), ~/.config/containers/podman/machine/ for machine config
- size: absent here (measured here, ~/.orbstack and ~/.local/share/containers not present)
- class: ask-first
- removal: `podman machine rm` removes the VM, its image, connections and ignition files, `--force` skips the prompt (reported online, https://docs.podman.io/en/latest/markdown/podman-machine-rm.1.html); OrbStack removal (unverified)
- regen: all containers, images and volumes in that machine are lost; recreate with `podman machine init`
- growth: VM image grows with container data; Podman path shown by the docs is the QEMU example only
- source: https://docs.podman.io/en/latest/markdown/podman-machine-rm.1.html fetched 2026-11-18

### local-k8s-clusters
- what: kind, k3d and minikube local Kubernetes clusters; kind and k3d run nodes as Docker containers, minikube has profiles under ~/.minikube
- catalog-id: none
- paths: ~/.minikube, ~/.kube/config (kubeconfig, edited by kind); node containers inside Docker.raw
- size: no clusters or ~/.minikube found here (measured here, du -sk ~/.minikube absent)
- class: ask-first
- removal: `kind delete cluster --name <name>` (reported online, https://kind.sigs.k8s.io/docs/user/quick-start/); `k3d cluster delete <name>` or `--all` (reported online, https://k3d.io/stable/usage/commands/k3d_cluster_delete/); `minikube delete` with `--all` for every profile, `--purge` also deletes ~/.minikube (reported online, https://minikube.sigs.k8s.io/docs/commands/delete/)
- regen: cluster state and workloads lost; recreating needs a node image pull (kind needs 6 GB VM memory to build node images, 8 GB recommended, same kind page)
- growth: each node is a container; multi-node configs multiply it; delete idle clusters
- source: https://kind.sigs.k8s.io/docs/user/quick-start/ and https://minikube.sigs.k8s.io/docs/commands/delete/ fetched 2026-11-18

### kube-cache
- what: kubectl discovery and HTTP cache
- catalog-id: kube-cache
- paths: ~/.kube/cache
- size: ~/.kube is 0 KB here (measured here); the cache holds discovery data and HTTP cache entries (reported online, https://kubernetes.io/docs/reference/kubectl/kubectl/)
- class: safe-regenerable
- removal: rm-verified (cache only; never touch ~/.kube/config)
- regen: kubectl refetches API discovery on next use, a short delay with network
- growth: grows per cluster context, usually small; default set by `--cache-dir` ($HOME/.kube/cache) (reported online, same page)
- source: https://kubernetes.io/docs/reference/kubectl/kubectl/ fetched 2026-11-18

### terraform-plugin-cache
- what: shared Terraform and OpenTofu provider plugin cache, enabled only if configured
- catalog-id: none
- paths: value of `plugin_cache_dir` in ~/.terraformrc or TF_PLUGIN_CACHE_DIR; docs example ~/.terraform.d/plugin-cache
- size: not present here (measured here, ~/.terraform.d absent)
- class: safe-regenerable
- removal: engine finds it in code, only when $TF_PLUGIN_CACHE_DIR is set, is a real dir under $HOME and looks like a provider cache; rm-verified; Terraform never prunes it and does not re-create the directory (reported online, https://developer.hashicorp.com/terraform/cli/config/config-file)
- regen: providers re-downloaded on next `terraform init` (network, tens to hundreds of MB each, (unverified))
- growth: grows with each provider version used; the directory must exist before use, Terraform will not create it; OpenTofu uses the same variable name ((unverified))
- source: https://developer.hashicorp.com/terraform/cli/config/config-file fetched 2026-11-18

### terraform-project-dirs
- what: per-project .terraform directory holding downloaded providers and modules when no shared cache is set
- catalog-id: none
- paths: <project>/.terraform
- size: (unverified) typically hundreds of MB per project; without a cache plugins download into the working directory (reported online, https://developer.hashicorp.com/terraform/cli/config/config-file)
- class: safe-regenerable
- removal: engine finds it in code: per git project, only when *.tf sits beside it and git check-ignore proves it ignored; rm-verified; never delete terraform.tfstate or .terraform.lock.hcl
- regen: `terraform init` re-downloads (network)
- growth: one copy per project per provider set; a shared plugin_cache_dir lets projects reuse downloads
- source: https://developer.hashicorp.com/terraform/cli/config/config-file fetched 2026-11-18 (the page does not name .terraform; directory name (unverified) from tool knowledge)

### pulumi-home
- what: Pulumi CLI home holding plugins, workspaces, templates and the credentials file
- catalog-id: none
- paths: ~/.pulumi (PULUMI_HOME moves it)
- size: not present here (measured here)
- class: ask-first
- removal: `pulumi plugin rm` for unused plugins (command (unverified)); never delete the credentials file without asking
- regen: plugins re-downloaded on next `pulumi up`; credentials need `pulumi login` again
- growth: grows with each provider plugin version
- source: https://www.pulumi.com/docs/iac/cli/environment-variables/ fetched 2026-11-18

### ansible-home
- what: Ansible home directory with temp files, installed collections and galaxy cache
- catalog-id: none
- paths: ~/.ansible (ANSIBLE_HOME), ~/.ansible/tmp, ~/.ansible/collections, ~/.ansible/galaxy_cache
- size: not present here (measured here)
- class: ask-first
- removal: rm-verified on tmp and galaxy_cache; collections are installed content, re-install with `ansible-galaxy collection install`
- regen: collections re-downloaded (network); tmp is recreated
- growth: collections accumulate per version
- source: https://docs.ansible.com/ansible/latest/reference_appendices/config.html fetched 2026-11-18

### vagrant-boxes
- what: Vagrant base boxes downloaded for VMs, stored in VAGRANT_HOME
- catalog-id: vagrant-boxes
- paths: ~/.vagrant.d/boxes (VAGRANT_HOME default ~/.vagrant.d)
- size: 600808 KB (~587 MB) boxes, ubuntu-VAGRANTSLASH-focal64 (measured here); docs warn it can become quite large (reported online, https://developer.hashicorp.com/vagrant/docs/other/environmental-variables)
- class: ask-first
- removal: catalog row is REPORT-ONLY (apply refuses): `vagrant box list`, then `vagrant box remove NAME` per box, or `vagrant box prune` for old versions (`--dry-run` first) (reported online, https://developer.hashicorp.com/vagrant/docs/cli/box)
- regen: box re-downloaded on next `vagrant up` (network, hundreds of MB); existing VMs made from it keep their own disks
- growth: each box version is a full image; budget 2 GB (suggested)
- source: https://developer.hashicorp.com/vagrant/docs/cli/box fetched 2026-11-18

### virtualbox-vms
- what: VirtualBox machine folders with VM disk images, snapshots and logs; user data
- catalog-id: none
- paths: ~/VirtualBox VMs, ~/Library/VirtualBox (global config)
- size: 992 KB total: 3tier-production-server 792 KB, VagrantFiles_default_1754343263067_92441 200 KB (measured here); folder layout reported online, https://www.virtualbox.org/manual/ch10.html
- class: never
- removal: none by the engine; the user removes a VM in VirtualBox or `VBoxManage unregistervm <name> --delete`, which destroys its disks (command (unverified))
- regen: none; the VM and everything inside it are lost
- growth: disk images grow dynamically; snapshots add differencing disks; the Vagrant-made VM above is recreated by `vagrant up`
- source: https://www.virtualbox.org/manual/ch10.html fetched 2026-11-18; sizes measured on this host 2026-11-18

### aws-cli-dir
- what: AWS CLI config, credentials and SSO login cache
- catalog-id: none
- paths: ~/.aws (config, credentials, sso/cache, cli/cache)
- size: 353440 KB (~345 MB) total, almost all in ~/.aws/amazonq at 349584 KB; atx 3828 KB; config and credentials 4 KB each (measured here); what amazonq holds is (unverified)
- class: never
- removal: report-only; config and credentials are secrets and settings; the amazonq subdir is another tool's data (unverified), ask first
- regen: credentials cannot be regenerated locally; SSO tokens return with `aws sso login`
- growth: the CLI part stays small; the large part here is not the AWS CLI
- source: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html fetched 2026-11-18 (config and credentials files confirmed; cache dirs (unverified)); sizes measured on this host 2026-11-18

### gcloud-config
- what: gcloud CLI configurations and credentials
- catalog-id: none
- paths: ~/.config/gcloud (CLOUDSDK_CONFIG overrides)
- size: 112 KB (measured here)
- class: never
- removal: report-only; to print the path use `gcloud info --format='value(config.paths.global_config_dir)'` (reported online, https://docs.cloud.google.com/sdk/docs/configurations)
- regen: `gcloud auth login` again; configurations lost
- growth: logs under the directory can grow (unverified)
- source: https://docs.cloud.google.com/sdk/docs/configurations fetched 2026-11-18

### azure-cli-dir
- what: Azure CLI config, tokens and optional logs
- catalog-id: none
- paths: ~/.azure (AZURE_CONFIG_DIR), logs default to ${AZURE_CONFIG_DIR}/logs
- size: 84 KB (measured here)
- class: never
- removal: report-only; logs only if enabled, rm-verified on the logs dir after asking
- regen: `az login` again
- growth: logs grow only when `logging.enable_log_file` is on
- source: https://learn.microsoft.com/en-us/cli/azure/azure-cli-configuration fetched 2026-11-18

### helm-cache
- what: Helm chart repository index cache and downloaded charts, plus config and data dirs
- catalog-id: helm-cache
- paths: ~/Library/Caches/helm (HELM_CACHE_HOME), ~/Library/Preferences/helm (HELM_CONFIG_HOME), ~/Library/helm (HELM_DATA_HOME)
- size: not present here (measured here, ~/Library/Caches/helm absent)
- class: safe-regenerable
- removal: rm-verified on the cache dir only; leave the config dir (repo list) alone
- regen: `helm repo update` refetches indexes (network)
- growth: small, per repo and chart version
- source: https://helm.sh/docs/helm/helm/ fetched 2026-11-18

### homebrew-cache
- what: Homebrew download cache of bottles and casks
- catalog-id: homebrew-cache
- paths: ~/Library/Caches/Homebrew (`brew --cache`, HOMEBREW_CACHE overrides)
- size: 64028 KB (~63 MB) (measured here)
- class: safe-regenerable
- removal: `brew cleanup -s` (`-s` also clears downloads of the latest versions; `-n` dry-run) (reported online, https://docs.brew.sh/Manpage)
- regen: bottles re-downloaded on next install (network)
- growth: auto cleanup runs after install, upgrade and reinstall unless HOMEBREW_NO_INSTALL_CLEANUP is set; downloads older than 120 days removed by default (reported online, https://docs.brew.sh/Manpage)
- source: https://docs.brew.sh/Manpage fetched 2026-11-18

### homebrew-old-versions
- what: Cellar versions of formulae superseded by upgrades, and orphaned dependencies
- catalog-id: none
- paths: /opt/homebrew/Cellar/<formula>/<old version>
- size: (unverified) not measured here
- class: safe-regenerable
- removal: `brew cleanup` removes old versions of installed formulae (`-n` first); `brew autoremove` uninstalls formulae installed only as dependencies and no longer needed (reported online, https://docs.brew.sh/Manpage); autoremove is ask-first because something may be used without being tracked
- regen: old versions are reinstalled only by explicit request (pinned or rollback needs)
- growth: one extra copy per upgrade until cleanup
- source: https://docs.brew.sh/Manpage fetched 2026-11-18

### act-images
- what: `act` (run GitHub Actions locally) pulls large runner Docker images and caches actions
- catalog-id: none
- paths: images inside Docker.raw; action cache path (unverified, possibly ~/.cache/act)
- size: (unverified); not found here (measured here, ~/.cache/act absent)
- class: ask-first
- removal: `docker image rm <image>` or `docker image prune -a` for the images (reported online, https://docs.docker.com/engine/manage-resources/pruning/); act's own cleanup (unverified)
- regen: images re-pulled on next run (network, large); `--action-offline-mode` reuses them (reported online, https://nektosact.com/usage/index.html)
- growth: one image per runner type used
- source: https://nektosact.com/usage/index.html fetched 2026-11-18

## Developer habits
- Runs databases and services in Docker Compose, so named volumes accumulate real data next to disposable images and build cache.
- Rebuilds images often, so BuildKit cache grows and stays "reclaimable" until pruned.
- Keeps Vagrant boxes and VirtualBox VMs from older projects after switching to containers.
- Uses cloud CLIs whose config dirs are credentials, not caches.
- Per-project .terraform directories repeat provider downloads when no shared plugin cache is set.

## Signals
- Dirs: ~/Library/Containers/com.docker.docker, ~/.docker, ~/.vagrant.d, ~/VirtualBox VMs, ~/.kube, ~/.aws, ~/.config/gcloud, ~/.azure, ~/.minikube, ~/.colima, ~/.lima, ~/.pulumi, ~/.ansible
- Files in projects: Dockerfile, docker-compose.yml, compose.yaml, *.tf, .terraform.lock.hcl, Vagrantfile, Chart.yaml, playbook.yml, Pulumi.yaml
- Commands: docker, kubectl, helm, terraform, tofu, pulumi, ansible, vagrant, VBoxManage, aws, gcloud, az, kind, minikube, k3d, colima, limactl, podman, act, brew

## Not covered / open questions
- OrbStack paths and reclaim steps: its docs page returned 404.
- What ~/.aws/amazonq (350 MB here) is and whether it can be cleared.
- Lima cache path, Colima delete/prune and act cache path were not confirmed by official pages.
- OpenTofu specifics (plugin cache variable) not fetched.
- Sizes of Cellar old versions and per-project .terraform dirs were not measured.
- Docker Desktop default max disk size not confirmed (docs example shows 64 GB, a sample only).
