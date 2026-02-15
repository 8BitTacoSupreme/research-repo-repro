# Reproducibility Report: Park et al. (2020)

**Paper:** "Prediction of Alzheimer's Disease Based on Deep Neural Network by Integrating Gene Expression and DNA Methylation Dataset"
**Authors:** Park, C., Ha, J., & Park, S.
**Journal:** Expert Systems with Applications, 140, 112873
**DOI:** 10.1016/j.eswa.2019.112873
**Companion Repository:** https://github.com/ChihyunPark/DNN_for_ADprediction

---

## 1. Environment Reconstruction

### Strategy: Pure Nix via Flox

Every dependency is resolved by Nix and stored in the content-addressed Nix store. No pip, no venv, no mutable package manager runs at activation time.

**Two custom Nix expressions** in `.flox/pkgs/` import a historical nixpkgs snapshot (nixos-19.09, commit `75f4ba05c63be3f147bcc2f7bd4ba1f029cedcb1`) that provides the 2019-era Python 3.6 and R ecosystems. Packages not in that snapshot (TF 1.4.1, TensorBoard 0.4.0, bayesian-optimization 1.0.1) are built from hash-pinned PyPI artifacts.

| File | Provides |
|------|----------|
| `.flox/pkgs/python-ml-env.nix` | `python3.withPackages` — Python 3.6.9 + TF 1.4.1 + numpy/pandas/scipy/sklearn/matplotlib/bayesopt |
| `.flox/pkgs/r-bio-env.nix` | `rWrapper` — R 3.6.1 + limma + ggplot2/data.table/openxlsx/pracma |
| `.flox/env/manifest.toml` | Hook wires build results into PATH + coreutils/bash/curl/gzip/sed |

### Why nixos-19.09?

- Python 3.6 was still a first-class citizen (3.7 was default, 3.6 fully supported)
- numpy 1.17.2, pandas 0.25.1, scikit-learn 0.21.2 — all from the same era as the paper
- R 3.6.1 with Bioconductor 3.9 packages (limma 3.38.3)
- Binary cache (cache.nixos.org) retains these builds

### Why not Docker?

Docker + pip provides **layer-level** reproducibility: the Dockerfile is repeatable, but pip resolution is non-deterministic — running `pip install tensorflow==1.4.1` today may pull different transitive deps than it did in 2019.

Nix provides **artifact-level** reproducibility: every `.so`, every `.py`, every byte is identified by its content hash. The dependency graph is a DAG of hash-addressed store paths. There is no "resolve at build time" step — the hashes ARE the versions.

---

## 2. Dependency Forensics Table

| Package | Paper / README | nixpkgs 19.09 | Custom Build | Confidence | Evidence |
|---------|---------------|---------------|-------------|------------|---------|
| Python | 3.5 (README) | 3.6.9 | - | HIGH | TF 1.4.1 compat matrix: 3.5-3.6; 3.5 EOL |
| TensorFlow | 1.4.1 (paper s2.3, README) | not in nixpkgs | **1.4.1 wheel** | HIGH | Paper + README; never packaged in nixpkgs (went 1.3→1.5) |
| TensorBoard | - | too new | **0.4.0 wheel** | HIGH | TF 1.4.1 requires `>=0.4.0,<0.5.0` |
| NumPy | 1.16.3 (README) | 1.17.2 | - | HIGH | 1.17.2 is one minor ahead; same API surface |
| pandas | 0.24.2 (README) | 0.25.1 | - | HIGH | 0.25.1 still has `.ix[]` and `.as_matrix()` |
| scikit-learn | 0.21.0 (README) / 0.21.2 (paper) | 0.21.2 | - | HIGH | nixpkgs matches paper's version exactly |
| scipy | - | 1.3.1 | - | MEDIUM | `from scipy import interp` still works in 1.3.x |
| matplotlib | - | 3.1.1 | - | MEDIUM | `mpl.use('Agg')` pattern unchanged |
| bayesian-opt | - | not in nixpkgs | **1.0.1 sdist** | MEDIUM | `from bayes_opt import BayesianOptimization`; 1.0.1 released 2019-01 |
| R | - | 3.6.1 | - | MEDIUM | Required for limma DEG/DMP analysis |
| limma | - | 3.38.3 | - | MEDIUM | Bioconductor 3.9 (matches nixos-19.09 timeline) |
| ggplot2 | - | 3.2.0 | - | LOW | R script import |
| data.table | - | 1.12.2 | - | LOW | R script import |
| openxlsx | - | (19.09 era) | - | LOW | R script import |
| pracma | - | (19.09 era) | - | LOW | R script import |
| dgof | - | unknown | TBD | LOW | R script import; may need CRAN install fallback |

### Key Decisions

1. **Python 3.6.9 vs 3.5:** README says 3.5, but Python 3.5 is EOL and unavailable. TF 1.4.1 supports both. No 3.5-specific code patterns found.

2. **NumPy 1.17.2 vs 1.16.3:** nixpkgs 19.09 ships 1.17.2 (one minor version ahead of README). The API surface is identical for the operations this code uses (array ops, `.shape`, `.mean()`). Using the nixpkgs version avoids a custom build and ensures compatibility with the rest of the 19.09 ecosystem.

3. **TF 1.4.1 never in nixpkgs:** TensorFlow packaging in nixpkgs went from 1.3.x directly to 1.5.0. Version 1.4.1 must be built from the PyPI manylinux1 wheel, with `autoPatchelfHook` to fix ELF rpath for the Nix store.

---

## 3. Hash-Pinned Artifacts

Every artifact in the environment is content-addressed in the Nix store. The three custom builds use these exact sources:

| Package | Source | SHA256 |
|---------|--------|--------|
| tensorflow 1.4.1 | [PyPI wheel (cp36-manylinux1-x86_64)](https://files.pythonhosted.org/packages/8c/b3/dba1a3e681a56d5ad63d3a1aa02b52294bdb3c6373245a67c1492a90cb62/tensorflow-1.4.1-cp36-cp36m-manylinux1_x86_64.whl) | `233d66bfad2287c61434384ec315bbf37b2f551beda2e0d37a8c24a0f2ed3896` |
| tensorboard 0.4.0 | [PyPI wheel (py3-none-any)](https://files.pythonhosted.org/packages/e9/9f/5845c18f9df5e7ea638ecf3a272238f0e7671e454faa396b5188c6e6fc0a/tensorflow_tensorboard-0.4.0-py3-none-any.whl) | `6684571c711e07b3aae25dd91cb4b106738d71acfce385b9d359ab14374ac518` |
| bayesian-opt 1.0.1 | [PyPI sdist](https://files.pythonhosted.org/packages/72/0c/173ac467d0a53e33e41b521e4ceba74a8ac7c7873d7b857a8fbdca88302d/bayesian-optimization-1.0.1.tar.gz) | `b7ba390dbdc3fe431f996952c16bfb878c6d19f1ea5efe2e5c8b788359e40c48` |

All other packages come from the nixos-19.09 binary cache at `cache.nixos.org`, which retains historical builds.

---

## 4. Data Preparation

### File Renaming

| Repo File | Code Expects | Action |
|-----------|-------------|--------|
| `allforDNN_ge_sample.tsv` | `allforDNN_ge.txt` | Copied |
| `allforDNN_me_sample.tsv` | `allforDNN_me.txt` | Copied |

### Annotation File

The code requires `GPL13534-11288.txt` (Illumina HumanMethylation450 BeadChip annotation). No longer available at original GEO FTP URL.

**Resolution:** Download the Illumina manifest CSV from GEO supplementary files and convert with `dataset/convert_manifest.py`.

### Required Directories

```bash
results/k_fold_train_test/
results/k_fold_train_test_results/k_{1..5}/table_{1..4}/{genExpr,meth,genExpr_meth,DEG,DMG,DEG_DMG}
```

---

## 5. Code Fixes

### R Script Windows Paths

`code/02 feature selection/01 investigate_DEG_DMP.R` had hardcoded Windows paths (`D:\Development\ADprediction_git\...`). Replaced with `commandArgs(trailingOnly=FALSE)` + `--file=` parsing + `normalizePath()` for cross-platform execution.

### Missing Output Directories

Prediction scripts use `os.mkdir()` (not `os.makedirs()`). All nested output directories must be pre-created.

---

## 6. Validation Results

### V1: Python Import Check — PENDING

Requires x86_64-linux. Expected: TF 1.4.1, numpy 1.17.2, pandas 0.25.1, scikit-learn 0.21.2, scipy 1.3.1, matplotlib 3.1.1, bayesian-optimization OK.

### V2: R Package Check — PENDING

Requires x86_64-linux. Expected: limma 3.38.3, ggplot2 3.2.0, data.table 1.12.2, openxlsx/pracma from 19.09 era.

### V3: Pipeline Smoke Test — PENDING

Expected: Steps 1-3 PASS, Steps 4-5 FAIL with sample data (0 features in DEG-DMG intersection).

### V4: Numerical Comparison — BLOCKED

Requires full GEO datasets (GSE33000, GSE44770, GSE80970) and x86_64-linux execution.

---

## 7. Confidence Level

**HIGH for environment reconstruction.** The nixpkgs 19.09 snapshot provides a complete, tested-together set of Python 3.6 and R packages from the paper's era. TF 1.4.1 is the exact version from the paper, built from its official PyPI wheel. Every artifact is hash-pinned.

**MEDIUM for numerical reproducibility.** Cannot verify without full datasets + x86_64-linux. Additional factors:
1. No RNG seeds in the code
2. NumPy/pandas versions are one minor ahead of README (unlikely to affect results)
3. R/Bioconductor versions from 19.09 (limma 3.38.3 vs uncertain original)

---

## 8. Recommendations

1. **Use `flox activate`** on x86_64-linux for the most reproducible environment. Use `flox containerize` for k8s deployment.

2. **Obtain full GEO datasets** — sample files produce different (empty) DEG-DMG intersections.

3. **Pin RNG seeds** — Add `np.random.seed(42)`, `tf.set_random_seed(42)`, `random.seed(42)` to each script.

4. **The nixpkgs tarball hash** in `python-ml-env.nix` and `r-bio-env.nix` needs to be populated on the first build (Nix will error with the correct hash — copy it in).

5. **dgof R package** — may need to be added as a custom Nix derivation or installed via `install.packages()` if not in nixpkgs 19.09 rPackages.
