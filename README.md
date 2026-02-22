# Computational Reproducibility: Park et al. (2020)

Reproducibility reconstruction of **"Prediction of Alzheimer's Disease Based on Deep Neural Network by Integrating Gene Expression and DNA Methylation Dataset"** by Park, Ha, & Park (2020).

- **Paper DOI:** [10.1016/j.eswa.2019.112873](https://doi.org/10.1016/j.eswa.2019.112873)
- **Original Repository:** [ChihyunPark/DNN_for_ADprediction](https://github.com/ChihyunPark/DNN_for_ADprediction)

## Overview

This project reconstructs the exact software environment from the 2019-era paper using **Flox** — a Nix-based declarative environment manager. Every dependency is hash-pinned in the Nix store. No pip, no Docker, no mutable state.

The environment imports a **historical nixpkgs snapshot** (nixos-19.09, commit `75f4ba05c63`) that provides Python 3.6.9, R 3.6.1, and the complete 2019-era scientific computing stack. TensorFlow 1.4.1 is built from its hash-pinned PyPI wheel since it was never packaged in nixpkgs.

CI builds run on every push via GitHub Actions on native x86_64-linux runners.

See [`DNN_for_ADprediction/REPRODUCIBILITY_REPORT.md`](DNN_for_ADprediction/REPRODUCIBILITY_REPORT.md) for the full forensic analysis, dependency table, and validation results.

## Repository Structure

```
research-repo-repro/
├── README.md
├── CLAUDE.md                              # Agent instructions
├── .github/workflows/flox-build.yml       # CI: build + verify + push to FloxHub
├── park-et-al-2020.md                     # Task brief
├── DNN_for_ADprediction/                  # Companion repo + reproducibility infra
│   ├── .flox/
│   │   ├── env/manifest.toml              # Flox manifest (pure Nix, no pip)
│   │   └── pkgs/
│   │       ├── python-ml-env.nix          # Python 3.6 + TF 1.4.1 + ML stack
│   │       └── r-bio-env.nix              # R + limma + CRAN packages
│   ├── REPRODUCIBILITY_REPORT.md          # Full reproducibility report
│   ├── code/                              # Pipeline scripts (R fix applied)
│   │   ├── 01 data preprocessing/
│   │   ├── 02 feature selection/
│   │   ├── 03 hyperparameter search/
│   │   └── 04 prediction/
│   ├── dataset/
│   │   ├── allforDNN_ge_sample.tsv
│   │   ├── allforDNN_me_sample.tsv
│   │   └── convert_manifest.py
│   └── results/
└── tasks/
```

## Prerequisites

- **[Flox](https://flox.dev/get-flox)** installed
- **x86_64-linux** system (TF 1.4.1 wheel is x86_64 only — see [macOS instructions](#on-macos-apple-silicon) below)
- ~5 GB disk for Nix store artifacts

## Quick Start

### On x86_64-linux (native)

```bash
git clone https://github.com/8BitTacoSupreme/research-repo-repro.git
cd research-repo-repro/DNN_for_ADprediction

# Build both environments (~5 min with binary cache)
flox build

# Verify
./result-python-ml-env/bin/python3 -c "import tensorflow as tf; print(tf.__version__)"
# → 1.4.1

./result-r-bio-env/bin/R --slave -e "library(limma); cat('limma loaded\n')"
# → limma loaded

# Run the pipeline
./result-python-ml-env/bin/python3 code/01\ data\ preprocessing/Split_Inputdata.py
```

`flox build` creates two symlinks:
- `result-python-ml-env` — Python 3.6.9 with TF 1.4.1, NumPy, pandas, scikit-learn, scipy, matplotlib, bayesian-optimization
- `result-r-bio-env` — R 3.6.1 with limma, ggplot2, data.table, openxlsx, pracma

### On macOS (Apple Silicon)

You cannot build directly — TF 1.4.1 has no ARM wheel. Options:

1. **Push to GitHub** — the CI workflow builds on native x86_64 ubuntu-latest automatically
2. **Lima VM** — run an x86_64 Linux VM locally:
   ```bash
   brew install lima
   limactl create --name=nix-builder --vm-type=vz --rosetta template://default
   limactl start nix-builder
   limactl shell nix-builder    # then install Flox inside and build
   ```
3. **Any x86_64 Linux box** — Linode, EC2, lab server, etc.

### Using `flox activate` (interactive shell)

```bash
cd DNN_for_ADprediction
flox activate
# Now python3, R, and all packages are on PATH
python3 -c "import tensorflow; print(tensorflow.__version__)"
```

## CI/CD

GitHub Actions builds both environments on every push to `flox-only` or `main`:

```
.github/workflows/flox-build.yml
```

The workflow:
1. Checks out the repo
2. Installs Flox via `flox/install-flox-action@v2`
3. Runs `flox build` (builds both Python and R environments)
4. Verifies Python packages: TF 1.4.1, NumPy 1.17.2, pandas 0.25.1, scikit-learn 0.21.2
5. Verifies R packages: R 3.6.1, limma 3.38.3
6. Pushes to FloxHub (requires `FLOX_FLOXHUB_TOKEN` repo secret)

## Preparing Data

```bash
# Copy sample data to expected filenames
cp dataset/allforDNN_ge_sample.tsv dataset/allforDNN_ge.txt
cp dataset/allforDNN_me_sample.tsv dataset/allforDNN_me.txt

# Download and convert Illumina 450K annotation
cd dataset
curl -L -o GPL13534_manifest.csv.gz \
  "https://ftp.ncbi.nlm.nih.gov/geo/platforms/GPL13nnn/GPL13534/suppl/GPL13534_HumanMethylation450_15017482_v.1.1.csv.gz"
python3 convert_manifest.py
cd ..

# Create output directories
mkdir -p results/k_fold_train_test
for k in 1 2 3 4 5; do
  mkdir -p results/k_fold_train_test_results/k_${k}/table_{1,2,3,4}/{genExpr,meth,genExpr_meth,DEG,DMG,DEG_DMG}
done
```

## Running the Pipeline

```bash
# Step 1: Data preprocessing
cd "code/01 data preprocessing" && python3 Split_Inputdata.py && cd ../..

# Step 2: Feature selection (DEG/DMP via limma)
cd "code/02 feature selection" && Rscript "01 investigate_DEG_DMP.R" && cd ../..

# Step 3: Annotate DMPs
cd "code/02 feature selection" && python3 "02 Annotate_DMP.py" && cd ../..

# Steps 4-5 require full GEO datasets (see below)
```

Steps 1-3 work with sample data. Steps 4-5 need full GEO datasets for meaningful results.

## What's Pinned

```
nixpkgs snapshot: nixos-19.09 (commit 75f4ba05c63be3f147bcc2f7bd4ba1f029cedcb1)
├── python36          3.6.9         (from binary cache)
├── numpy             1.17.2        (from binary cache)
├── pandas            0.25.1        (from binary cache, tests disabled)
├── scikit-learn      0.21.2        (from binary cache)
├── scipy             1.3.1         (from binary cache)
├── matplotlib        3.1.1         (from binary cache)
├── R                 3.6.1         (from binary cache)
├── limma             3.38.3        (from binary cache)
├── ggplot2           3.2.0         (from binary cache)
├── data.table        1.12.2        (from binary cache)
├── openxlsx          (19.09 era)   (from binary cache)
├── pracma            (19.09 era)   (from binary cache)
└── CUSTOM BUILDS:
    ├── tensorflow    1.4.1         (PyPI wheel sha256:233d66bf...)
    ├── tensorboard   0.4.0         (PyPI wheel sha256:6684571c...)
    └── bayesian-opt  1.0.1         (PyPI sdist sha256:b7ba390d...)
```

## Build Fixes

The Nix expressions required several fixes to build correctly in a sandboxed environment:

1. **pandas test skip** — pandas' test dependency chain (moto -> boto -> httpretty) has timing-sensitive tests that fail in sandboxed/emulated builds. Disabled via `overrideAttrs`.

2. **pip `--no-deps`** — pip inside the Nix sandbox can't see Nix-provided packages, so dependency checks fail for TF and TensorBoard wheels. Fixed with `pipInstallFlags = ["--no-deps"]`.

3. **manylinux1 wheel rename** — the TF 1.4.1 wheel uses the `manylinux1_x86_64` platform tag, which pip rejects in the Nix sandbox (no `/lib/x86_64-linux-gnu`). Fixed by renaming to `linux_x86_64` in a custom `unpackPhase`, then using `autoPatchelfHook` to fix shared library RPATHs.

4. **TensorBoard binary collision** — both TensorBoard 0.4.0 and TF 1.4.1 install a `tensorboard` binary. Resolved by removing TensorBoard's `bin/` output.

## Architecture: Why Nix Instead of Docker

| | Docker (main branch) | Flox/Nix (this branch) |
|---|---|---|
| **Reproducibility** | Mutable pip installs cached in layers | Every artifact hash-pinned in Nix store |
| **Binary cache** | Docker Hub layers | cache.nixos.org (content-addressed) |
| **Dependency graph** | Opaque (pip resolves at build time) | Fully visible in Nix expressions |
| **Container export** | Dockerfile builds OCI image | `flox containerize` exports OCI image |
| **Activation time** | `docker run` (seconds) | `flox activate` (instant after first build) |
| **Auditability** | Read Dockerfile + hope pip resolves same | Read .nix files — every hash is the version |

## Full Datasets (for numerical reproduction)

To reproduce the paper's reported results (DNN accuracy 0.823, AUROC 0.797), download from GEO:

- [GSE33000](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE33000) — Gene expression (467 samples)
- [GSE44770](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE44770) — Gene expression (229 samples)
- [GSE80970](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE80970) — DNA methylation (142 samples)

> The code does not set random seeds, so exact numerical reproduction is not possible even with correct data. Results within 1-2% of paper values indicate successful environment reconstruction.

## Code Fixes Applied

1. **R script Windows paths** — `code/02 feature selection/01 investigate_DEG_DMP.R` had hardcoded `D:\Development\...` paths. Replaced with cross-platform path detection.

2. **Illumina annotation file** — `GPL13534-11288.txt` is no longer at its original GEO URL. Created `dataset/convert_manifest.py` to generate it from the Illumina supplementary CSV.

## License

Original code from [ChihyunPark/DNN_for_ADprediction](https://github.com/ChihyunPark/DNN_for_ADprediction). Reproducibility infrastructure (Flox manifest, Nix expressions, report, data conversion script) added by this project.
