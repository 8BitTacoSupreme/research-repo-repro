# Computational Reproducibility: Park et al. (2020)

Reproducibility reconstruction of **"Prediction of Alzheimer's Disease Based on Deep Neural Network by Integrating Gene Expression and DNA Methylation Dataset"** by Park, Ha, & Park (2020).

- **Paper DOI:** [10.1016/j.eswa.2019.112873](https://doi.org/10.1016/j.eswa.2019.112873)
- **Original Repository:** [ChihyunPark/DNN_for_ADprediction](https://github.com/ChihyunPark/DNN_for_ADprediction)

## Overview

This project reconstructs the exact software environment from the 2019-era paper using **Flox** — a Nix-based declarative environment manager. Every dependency is hash-pinned in the Nix store. No pip, no Docker, no mutable state.

The environment imports a **historical nixpkgs snapshot** (nixos-19.09, commit `75f4ba05c63`) that provides Python 3.6.9, R 3.6.1, and the complete 2019-era scientific computing stack. TensorFlow 1.4.1 is built from its hash-pinned PyPI wheel since it was never packaged in nixpkgs.

See [`DNN_for_ADprediction/REPRODUCIBILITY_REPORT.md`](DNN_for_ADprediction/REPRODUCIBILITY_REPORT.md) for the full forensic analysis, dependency table, and validation results.

## Repository Structure

```
research-repo-repro/
├── CLAUDE.md                              # Agent instructions
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

- **Flox** ([install](https://flox.dev/get-flox))
- **x86_64-linux** system (TF 1.4.1 has no arm64 wheel)
- ~5 GB disk for Nix store artifacts

## Quick Start

### 1. Build the environment (one-time)

```bash
cd DNN_for_ADprediction
flox build
```

This builds TF 1.4.1 from its PyPI wheel, TensorBoard 0.4.0, and bayesian-optimization 1.0.1 from source. All other packages (numpy, pandas, scipy, scikit-learn, matplotlib, R, limma, etc.) are fetched from the nixos-19.09 binary cache. Takes ~5 minutes on first run. Creates `result-python-ml-env` and `result-r-bio-env` symlinks.

### 2. Activate the environment

```bash
flox activate
```

The on-activate hook wires the build results into PATH. Subsequent activations are instant.

### 2. Prepare data files

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

### 3. Run the pipeline

```bash
# Step 1: Data preprocessing
cd "code/01 data preprocessing" && python3 Split_Inputdata.py && cd ../..

# Step 2: Feature selection (DEG/DMP via limma)
cd "code/02 feature selection" && Rscript "01 investigate_DEG_DMP.R" && cd ../..

# Step 3: Annotate DMPs
cd "code/02 feature selection" && python3 "02 Annotate_DMP.py" && cd ../..

# Steps 4-5 require full GEO datasets (see below)
```

## Deploying to Kubernetes (no Docker)

Flox exports native OCI container images directly from the Nix store:

```bash
# Export OCI image
flox containerize -f park2020-ad-dnn.tar

# Load into a container runtime
docker load < park2020-ad-dnn.tar
# OR
podman load < park2020-ad-dnn.tar

# Push to registry and deploy to k8s
docker tag park2020-ad-dnn:latest registry.example.com/park2020-ad-dnn:latest
docker push registry.example.com/park2020-ad-dnn:latest

kubectl create deployment park2020 --image=registry.example.com/park2020-ad-dnn:latest
```

The container image contains only the Nix closure — no base OS layer, no package manager. Minimal attack surface, fully reproducible.

## Testing

### Test 1: Verify Python environment

```bash
python3 -c "
import tensorflow as tf; print('TensorFlow:', tf.__version__)
import numpy as np; print('NumPy:', np.__version__)
import pandas as pd; print('pandas:', pd.__version__)
import sklearn; print('scikit-learn:', sklearn.__version__)
from bayes_opt import BayesianOptimization; print('bayesian-optimization: OK')
import matplotlib; print('matplotlib:', matplotlib.__version__)
import scipy; print('scipy:', scipy.__version__)
"
```

**Expected output:**
```
TensorFlow: 1.4.1
NumPy: 1.17.2
pandas: 0.25.1
scikit-learn: 0.21.2
bayesian-optimization: OK
matplotlib: 3.1.1
scipy: 1.3.1
```

> Note: NumPy/pandas/scipy/matplotlib versions differ from the pip-based branch because they come from nixpkgs 19.09 (same era, tested together). TF 1.4.1 is the exact version from the paper.

### Test 2: Verify R environment

```bash
Rscript -e "
library(limma); cat('limma:', as.character(packageVersion('limma')), '\n')
library(openxlsx); cat('openxlsx:', as.character(packageVersion('openxlsx')), '\n')
library(data.table); cat('data.table:', as.character(packageVersion('data.table')), '\n')
library(ggplot2); cat('ggplot2:', as.character(packageVersion('ggplot2')), '\n')
library(pracma); cat('pracma:', as.character(packageVersion('pracma')), '\n')
"
```

### Test 3: Pipeline smoke test

Steps 1-3 should PASS with sample data. Steps 4-5 will FAIL with `ValueError: 0 features` — this is expected because the sample `.tsv` files have too few probes for a meaningful DEG-DMG intersection. Full GEO datasets (GSE33000, GSE44770, GSE80970) are required for the prediction steps.

## Architecture: Why Nix Instead of Docker

| | Docker (main branch) | Flox/Nix (this branch) |
|---|---|---|
| **Reproducibility** | Mutable pip installs cached in layers | Every artifact hash-pinned in Nix store |
| **Binary cache** | Docker Hub layers | cache.nixos.org (content-addressed) |
| **Dependency graph** | Opaque (pip resolves at build time) | Fully visible in Nix expressions |
| **Container export** | Dockerfile builds OCI image | `flox containerize` exports OCI image |
| **Activation time** | `docker run` (seconds) | `flox activate` (instant after first build) |
| **Auditability** | Read Dockerfile + hope pip resolves same | Read .nix files — every hash is the version |

## What's Pinned

```
nixpkgs snapshot: nixos-19.09 (commit 75f4ba05c63be3f147bcc2f7bd4ba1f029cedcb1)
├── python36          3.6.9         (from binary cache)
├── numpy             1.17.2        (from binary cache)
├── pandas            0.25.1        (from binary cache)
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

## Code Fixes Applied

1. **R script Windows paths** — `code/02 feature selection/01 investigate_DEG_DMP.R` had hardcoded `D:\Development\...` paths. Replaced with cross-platform path detection.

2. **Illumina annotation file** — `GPL13534-11288.txt` is no longer at its original GEO URL. Created `dataset/convert_manifest.py` to generate it from the Illumina supplementary CSV.

## Full Datasets (for numerical reproduction)

To reproduce the paper's reported results (DNN accuracy 0.823, AUROC 0.797), download from GEO:

- [GSE33000](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE33000) — Gene expression (467 samples)
- [GSE44770](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE44770) — Gene expression (229 samples)
- [GSE80970](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE80970) — DNA methylation (142 samples)

> The code does not set random seeds, so exact numerical reproduction is not possible even with correct data. Results within 1-2% of paper values indicate successful environment reconstruction.

## License

Original code from [ChihyunPark/DNN_for_ADprediction](https://github.com/ChihyunPark/DNN_for_ADprediction). Reproducibility infrastructure (Flox manifest, Nix expressions, report, data conversion script) added by this project.
