# Task: Reproduce Park et al. 2020 — DNN for Alzheimer's Disease Prediction

## Paper

**Title**: Prediction of Alzheimer's disease based on deep neural network by integrating gene expression and DNA methylation dataset
**Authors**: Chihyun Park, Jihwan Ha, Sanghyun Park (Yonsei University)
**Journal**: Expert Systems With Applications, Volume 140, 2020
**DOI**: https://doi.org/10.1016/j.eswa.2019.112873

## Repository

https://github.com/ChihyunPark/DNN_for_ADprediction

---

## Known Version Anchors

| Package | Version | Confidence | Evidence |
|---------|---------|------------|----------|
| TensorFlow | 1.4.1 | **high** | Paper §2.3: "Google TensorFlow (version 1.4.1)" |
| scikit-learn | 0.21.2 | **high** | Paper §3.1: "Scikit-learn package (version 0.21.2)" |
| Limma (R/Bioconductor) | unspecified | low | Paper §2.2: used for DEG/DMP analysis |
| Python | ~3.5–3.6 | medium | Inferred: TF 1.4.1 supported Python 3.5–3.6 |

### Still needs identification from repo code:
- Bayesian optimization library (paper §2.3 describes the approach but does not name the Python package — likely `bayesian-optimization` or `GPyOpt`)
- NumPy version (constrained by TF 1.4.1 — must be <1.15)
- SciPy version
- Pandas version (if used)
- Any GEO data retrieval packages

---

## Timeline

| Event | Date |
|-------|------|
| TensorFlow 1.4.1 released | ~November 2017 |
| scikit-learn 0.21.2 released | May 2019 |
| Paper received by journal | February 8, 2019 |
| Paper revised | August 14, 2019 |
| Paper accepted | August 14, 2019 |
| Paper available online | August 15, 2019 |

**Note**: The TF version (late 2017) and scikit-learn version (mid 2019) are 18 months apart. This suggests the TF version was locked early in development and scikit-learn was upgraded later. The actual working environment likely dates to early 2019.

---

## Datasets

All from NCBI Gene Expression Omnibus (GEO):

| Dataset | GEO ID | Type | Samples |
|---------|--------|------|---------|
| Gene expression #1 | GSE33000 | Rosetta/Merck Human 44k 1.1 microarray | 157 normal, 310 AD |
| Gene expression #2 | GSE44770 | Same platform | 100 normal, 129 AD |
| DNA methylation | GSE80970 | Illumina HumanMethylation 450 BeadChip | 68 normal, 74 AD |

**Brain region**: Prefrontal cortex only (both datasets)
**Normalization**: Gene expression z-scored; DNA methylation M-values with quantile normalization

Verify these are still accessible at: https://www.ncbi.nlm.nih.gov/geo/

---

## Key Methodological Details

### Feature selection (§2.2)
- DEG: |fold change| ≥ 2, p-value < 0.01 (using Limma)
- DMP: |fold change| ≥ 1.5, p-value < 0.01, CpG within 1500bp of TSS
- Intersection at gene level → ~35 genes across 5 folds

### Sample generation (§2.2) — REPRODUCIBILITY RISK
The gene expression and DNA methylation profiles are from DIFFERENT samples. The authors created **all possible pairs** for each label:
- Normal: 257 × 68 = 17,476 combinations
- AD: 439 × 74 = 32,486 combinations

This combinatorial approach is unusual. Ordering, shuffling, and data structure implementation could affect results.

### DNN architecture (§2.3)
- 8 hidden layers, 306 nodes per layer
- ReLU activation, softmax output
- Learning rate: 0.02, Dropout: 0.85
- Max epochs: 1500, early stopping after epoch 100
- Cross-entropy loss, gradient descent optimization
- 5-fold cross-validation

### Hyperparameter search
- Bayesian optimization over: hidden layers (7–11), nodes (250–350), learning rate (0.01–0.2), dropout (0.6–0.9)

---

## Expected Results (Paper's Numbers)

| Metric | Value |
|--------|-------|
| Average test accuracy (DNN + DEG+DMP) | **0.823** |
| Average AUROC (DNN + DEG+DMP) | **0.797** |
| Best single fold accuracy | 0.872 (fold 3, using only MS4A4A and BEX2) |

Baseline comparisons: Random Forest best was 0.700, SVM was 0.526, Naïve Bayes was 0.626 (all with DEG+DMP features on integrated data).

---

## Known Challenges

1. **TF 1.4.1 + Python version lock**: TF 1.4.1 needs Python 3.5 or 3.6 and numpy <1.15. Modern systems don't ship these. This is the primary Nix time-machine use case.

2. **CUDA dependency**: TF 1.4.1 GPU support requires CUDA 8.0 and cuDNN 6.0. If the code was run on GPU, this adds another layer. CPU-only may be sufficient for validation since the dataset is small (~50K combined samples after pairing).

3. **R/Bioconductor for Limma**: The feature selection step uses R. Need to determine which Bioconductor version ships the Limma version compatible with the paper's analysis. Bioconductor 3.8 (R 3.5) or Bioconductor 3.9 (R 3.6) are likely candidates for early 2019.

4. **Bayesian optimization library**: Not named. Must be identified from repo imports.

5. **Combinatorial sample pairing**: The all-possible-combinations approach in §2.2 may be sensitive to implementation details (ordering, memory layout, random seeds in cross-validation splits).

6. **Early stopping**: The custom early stopping logic (compare 10-epoch moving average after epoch 100) is hand-coded — subtle differences in float comparison could shift the stopping point.
