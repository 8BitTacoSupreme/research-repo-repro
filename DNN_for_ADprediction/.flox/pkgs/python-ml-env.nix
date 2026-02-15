# Python 3.6 ML environment for Park et al. (2020)
#
# Strategy:
#   Import nixpkgs nixos-19.09 (the last release with full python36Packages).
#   Modern nixpkgs has python36 interpreter but its packages (numpy 1.20+) reject 3.6.
#   nixos-19.09 ships: Python 3.6.9, NumPy 1.17.2, pandas 0.25.1, scikit-learn 0.21.2,
#   scipy 1.3.1, matplotlib 3.1.1 — all from the paper's era.
#
# Custom builds from hash-pinned PyPI artifacts:
#   TensorFlow 1.4.1  — never packaged in nixpkgs (went 1.3→1.5)
#   TensorBoard 0.4.0 — required by TF 1.4.1 (>=0.4.0,<0.5.0)
#   bayesian-optimization 1.0.1 — not in nixpkgs
#
# Target: x86_64-linux only (TF 1.4.1 wheel is manylinux1 x86_64)

{ lib }:

let
  # Pin to final nixos-19.09 release.
  # Hardcode x86_64-linux: TF 1.4.1 only has manylinux1 wheels.
  # Binary cache (cache.nixos.org) retains these builds.
  nixpkgs-1909 = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/75f4ba05c63be3f147bcc2f7bd4ba1f029cedcb1.tar.gz";
    sha256 = "157c64220lf825ll4c0cxsdwg7cxqdx4z559fdp7kpz0g6p8fhhr";
  }) {
    system = "x86_64-linux";
    config = { allowUnfree = true; };
    overlays = [];
  };

  inherit (nixpkgs-1909) fetchurl;
  python = nixpkgs-1909.python36;
  pp = python.pkgs;

  # === TensorBoard 0.4.0 (required by TF 1.4.1: >=0.4.0,<0.5.0) ===
  tensorboard040 = pp.buildPythonPackage rec {
    pname = "tensorflow-tensorboard";
    version = "0.4.0";
    format = "wheel";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/e9/9f/5845c18f9df5e7ea638ecf3a272238f0e7671e454faa396b5188c6e6fc0a/tensorflow_tensorboard-0.4.0-py3-none-any.whl";
      sha256 = "6684571c711e07b3aae25dd91cb4b106738d71acfce385b9d359ab14374ac518";
    };
    propagatedBuildInputs = with pp; [ werkzeug html5lib bleach markdown numpy six ];
    doCheck = false;
  };

  # === TensorFlow 1.4.1 CPU from PyPI wheel ===
  tensorflow141 = pp.buildPythonPackage rec {
    pname = "tensorflow";
    version = "1.4.1";
    format = "wheel";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/8c/b3/dba1a3e681a56d5ad63d3a1aa02b52294bdb3c6373245a67c1492a90cb62/tensorflow-1.4.1-cp36-cp36m-manylinux1_x86_64.whl";
      sha256 = "233d66bfad2287c61434384ec315bbf37b2f551beda2e0d37a8c24a0f2ed3896";
    };
    propagatedBuildInputs = with pp; [
      numpy
      protobuf
      six
      werkzeug
      tensorboard040
    ];
    nativeBuildInputs = [ nixpkgs-1909.autoPatchelfHook ];
    buildInputs = [
      nixpkgs-1909.stdenv.cc.cc.lib  # libstdc++
      nixpkgs-1909.zlib
    ];
    doCheck = false;
  };

  # === bayesian-optimization 1.0.1 (not in nixpkgs, pure Python) ===
  bayesopt = pp.buildPythonPackage rec {
    pname = "bayesian-optimization";
    version = "1.0.1";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/72/0c/173ac467d0a53e33e41b521e4ceba74a8ac7c7873d7b857a8fbdca88302d/bayesian-optimization-1.0.1.tar.gz";
      sha256 = "b7ba390dbdc3fe431f996952c16bfb878c6d19f1ea5efe2e5c8b788359e40c48";
    };
    propagatedBuildInputs = with pp; [ numpy scipy scikitlearn ];
    doCheck = false;
  };

in python.withPackages (ps: [
  # Core ML stack (from nixpkgs 19.09 binary cache)
  ps.numpy       # 1.17.2
  ps.pandas      # 0.25.1
  ps.scikitlearn # 0.21.2
  ps.scipy       # 1.3.1
  ps.matplotlib  # 3.1.1

  # Custom builds (from hash-pinned PyPI artifacts)
  tensorflow141  # 1.4.1
  bayesopt       # 1.0.1
])
