# R environment with Bioconductor + CRAN packages for Park et al. (2020)
#
# Uses nixpkgs nixos-19.09 (same snapshot as python-ml-env.nix) which provides:
#   R 3.6.1 + rPackages including Bioconductor limma
#
# All R packages are pre-built by Nix. No install.packages() at runtime.
# Target: x86_64-linux only.

{ lib }:

let
  nixpkgs-1909 = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/75f4ba05c63be3f147bcc2f7bd4ba1f029cedcb1.tar.gz";
    sha256 = "157c64220lf825ll4c0cxsdwg7cxqdx4z559fdp7kpz0g6p8fhhr";
  }) {
    system = "x86_64-linux";
    config = { allowUnfree = true; };
    overlays = [];
  };

in nixpkgs-1909.rWrapper.override {
  packages = with nixpkgs-1909.rPackages; [
    # Bioconductor (DEG/DMP analysis)
    limma

    # CRAN packages used by the pipeline
    ggplot2
    data_table
    openxlsx
    pracma

    # dgof — uncomment if available in nixpkgs 19.09 rPackages
    # dgof
  ];
}
