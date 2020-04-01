# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ haskell-nix-src, nixpkgs }:

let
  flake = {
    edition = 201911;

    description = "Alternative Haskell Infrastructure for Nixpkgs";

    outputs = { self, nixpkgs }: {
      lib = rec {
        cleanSourceWith = (import "${haskell-nix-src}/lib/clean-source-with.nix" {
          lib = nixpkgs.lib;
        }).cleanSourceWith;
        cleanGit = import "${haskell-nix-src}/lib/clean-git.nix" {
          lib = nixpkgs.lib;
          inherit (nixpkgs) runCommand git;
          inherit cleanSourceWith;
        };
      };
    };
  };

  haskell-nix = flake.outputs {
    self = haskell-nix;
    inherit nixpkgs;
  };

in haskell-nix
