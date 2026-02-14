# Computational Reproducibility: Park et al. (2020)

Reproducibility reconstruction of **"Prediction of Alzheimer's Disease Based on Deep Neural Network by Integrating Gene Expression and DNA Methylation Dataset"** by Park, Ha, & Park (2020).

- **Paper DOI:** [10.1016/j.eswa.2019.112873](https://doi.org/10.1016/j.eswa.2019.112873)
- **Original Repository:** [ChihyunPark/DNN_for_ADprediction](https://github.com/ChihyunPark/DNN_for_ADprediction)

## Overview

This project reconstructs the exact software environment from the 2019-era paper using Docker (for cross-platform x86_64 emulation) and Flox (for declarative Nix-based environments). The environment includes TensorFlow 1.4.1, Python 3.6, R with Bioconductor/limma, and all supporting libraries at their original versions.

See [`DNN_for_ADprediction/REPRODUCIBILITY_REPORT.md`](DNN_for_ADprediction/REPRODUCIBILITY_REPORT.md) for the full forensic analysis, dependency table, validation results, and recommendations.

## Repository Structure

```
research-repo-repro/
├── CLAUDE.md                          # Agent instructions for reproducibility workflow
├── park-et-al-2020.md                 # Task brief with version anchors and timeline
├── DNN_for_ADprediction/              # Cloned + modified companion repo
│   ├── Dockerfile                     # Docker build (cross-platform, x86_64 emulation)
│   ├── .flox/env/manifest.toml        # Flox environment (native x86_64-linux)
│   ├── .dockerignore
│   ├── REPRODUCIBILITY_REPORT.md      # Full reproducibility report
│   ├── code/                          # Original pipeline scripts (R fix applied)
│   │   ├── 01 data preprocessing/     # Split_Inputdata.py
│   │   ├── 02 feature selection/      # 01 investigate_DEG_DMP.R (fixed), 02 Annotate_DMP.py
│   │   ├── 03 hyperparameter search/  # BayesianOpt_HpParm_Search.py
│   │   └── 04 prediction/             # AD_Prediction_ML.py, AD_Prediction_DNN.py
│   ├── dataset/
│   │   ├── allforDNN_ge_sample.tsv    # Sample gene expression data (original)
│   │   ├── allforDNN_me_sample.tsv    # Sample methylation data (original)
│   │   └── convert_manifest.py        # Converts Illumina manifest → GEO annotation format
│   └── results/                       # Pipeline output directories (gitignored)
└── tasks/                             # Task briefs (if present)
```

## Prerequisites

- **Docker Desktop** (with Rosetta / QEMU emulation enabled on Apple Silicon)
- ~3 GB disk space for the Docker image
- ~10 minutes for initial build

## Quick Start

### 1. Build the Docker image

```bash
cd DNN_for_ADprediction
docker build --platform linux/amd64 -t park2020-ad-dnn .
```

### 2. Run the container

```bash
docker run --platform linux/amd64 \
  -v "$(pwd)":/workspace -w /workspace \
  -it park2020-ad-dnn bash
```

### 3. Prepare data files (inside the container)

```bash
# Copy sample data to the filenames the code expects
cp dataset/allforDNN_ge_sample.tsv dataset/allforDNN_ge.txt
cp dataset/allforDNN_me_sample.tsv dataset/allforDNN_me.txt

# Download and convert the Illumina 450K annotation file
cd dataset
curl -L -o GPL13534_manifest.csv.gz \
  "https://ftp.ncbi.nlm.nih.gov/geo/platforms/GPL13nnn/GPL13534/suppl/GPL13534_HumanMethylation450_15017482_v.1.1.csv.gz"
python convert_manifest.py
cd ..

# Create output directories
mkdir -p results/k_fold_train_test
for k in 1 2 3 4 5; do
  mkdir -p results/k_fold_train_test_results/k_${k}/table_{1,2,3,4}/{genExpr,meth,genExpr_meth,DEG,DMG,DEG_DMG}
done
```

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
NumPy: 1.16.3
pandas: 0.24.2
scikit-learn: 0.21.0
bayesian-optimization: OK
matplotlib: 3.0.3
scipy: 1.2.1
```

### Test 2: Verify R environment

```bash
Rscript -e "
library(limma); cat('limma:', as.character(packageVersion('limma')), '\n')
library(openxlsx); cat('openxlsx:', as.character(packageVersion('openxlsx')), '\n')
library(data.table); cat('data.table:', as.character(packageVersion('data.table')), '\n')
library(ggplot2); cat('ggplot2:', as.character(packageVersion('ggplot2')), '\n')
library(pracma); cat('pracma:', as.character(packageVersion('pracma')), '\n')
library(dgof); cat('dgof:', as.character(packageVersion('dgof')), '\n')
"
```

**Expected output:**
```
limma: 3.46.0
openxlsx: 4.2.3
data.table: 1.14.0
ggplot2: 3.3.3
pracma: 2.3.3
dgof: 1.2
```

### Test 3: Run the pipeline (with sample data)

```bash
# Step 1: Data preprocessing (splits into 5-fold train/test)
cd "code/01 data preprocessing"
python Split_Inputdata.py
cd ../..

# Step 2: Feature selection — DEG and DMP analysis via limma
cd "code/02 feature selection"
Rscript "01 investigate_DEG_DMP.R"

# Step 3: Annotate DMPs with gene names
python "02 Annotate_DMP.py"
cd ../..

# Step 4: ML prediction (will fail with sample data — see note below)
cd "code/04 prediction"
python AD_Prediction_ML.py

# Step 5: DNN prediction (will fail with sample data — see note below)
python AD_Prediction_DNN.py
cd ../..
```

**Expected results:**
- Steps 1-3: **PASS** — Data preprocessing and feature selection complete successfully
- Steps 4-5: **FAIL** with `ValueError: 0 features` — This is expected with sample data. The `_sample.tsv` files contain only 200 genes and 500 CpG probes (vs ~20,000+ genes and ~485,000 probes in the full GEO datasets). The DEG-DMG intersection is empty with so few features. This is a **data limitation, not an environment issue**.

### Test 4: Full numerical reproduction (requires GEO datasets)

To reproduce the paper's reported results (DNN accuracy 0.823, AUROC 0.797), download the full datasets from GEO:

- [GSE33000](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE33000) — Gene expression (467 samples)
- [GSE44770](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE44770) — Gene expression (229 samples)
- [GSE80970](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE80970) — DNA methylation (142 samples)

Replace `dataset/allforDNN_ge.txt` and `dataset/allforDNN_me.txt` with the full datasets, then re-run the pipeline from Step 1.

> **Note:** The code does not set random seeds, so exact numerical reproduction is not possible even with correct data. Results within 1-2% of paper values indicate successful environment reconstruction.

## Alternative: Flox Environment (native x86_64-linux only)

On a native x86_64-linux system, you can use Flox instead of Docker:

```bash
cd DNN_for_ADprediction
flox activate
```

This uses the declarative environment in `.flox/env/manifest.toml`. The on-activate hook installs all Python and R packages automatically.

## Code Fixes Applied

1. **R script Windows paths** — `code/02 feature selection/01 investigate_DEG_DMP.R` had hardcoded `D:\Development\...` paths. Replaced with robust cross-platform path detection using `commandArgs()` and `normalizePath()`.

2. **Illumina annotation file** — `GPL13534-11288.txt` is no longer available at its original GEO URL. Created `dataset/convert_manifest.py` to generate it from the Illumina supplementary CSV.

## Dependency Forensics Summary

| Package | Pinned Version | Confidence | Key Evidence |
|---------|---------------|------------|--------------|
| Python | 3.6.14 | HIGH | README says 3.5; TF 1.4.1 compat matrix supports 3.5-3.6 |
| TensorFlow | 1.4.1 | HIGH | Paper Section 2.3 + README |
| NumPy | 1.16.3 | HIGH | README |
| pandas | 0.24.2 | HIGH | README; code uses deprecated `.ix[]` API |
| scikit-learn | 0.21.0 | HIGH | README |
| bayesian-optimization | 1.0.1 | MEDIUM | Import in code; 2019 release date |
| matplotlib | 3.0.3 | MEDIUM | `mpl.use('Agg')` pattern; 2019 era |
| scipy | 1.2.1 | MEDIUM | `from scipy import interp` (deprecated later) |
| R + limma | 4.0.4 + 3.46.0 | MEDIUM | Bioconductor for DEG/DMP analysis |

## License

The original code is from [ChihyunPark/DNN_for_ADprediction](https://github.com/ChihyunPark/DNN_for_ADprediction). Reproducibility infrastructure (Dockerfile, Flox manifest, report, and data conversion script) added by this project.
