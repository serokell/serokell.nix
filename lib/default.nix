# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ lib, gitignore-nix, nixpkgs, deploy-rs }: {
  src = import ./src.nix { inherit lib gitignore-nix; };

  # Extend nixpkgs with multiple overlays
  #   pkgs = pkgsWith nixpkgs.legacyPackages.${system} [ inputs.serokell-nix.overlay ];
  pkgsWith = p: e: p.extend (lib.composeManyExtensions e);

  haskell = import ./haskell.nix { inherit lib; };

  systemd = import ./systemd;

  types = import ./types.nix { inherit lib; };

  pipeline = import ./pipeline.nix { inherit lib nixpkgs deploy-rs; };

  terraform = import ./terraform.nix { inherit lib nixpkgs; };
}
