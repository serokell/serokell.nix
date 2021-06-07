# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ lib, gitignore-nix }:

rec {
  src = import ./src.nix { inherit lib gitignore-nix; };

  # Extend nixpkgs with multiple overlays
  #   pkgs = pkgsWith nixpkgs.legacyPackages.${system} [ inputs.serokell-nix.overlay ];
  pkgsWith = p: e: p.extend (lib.composeManyExtensions e);

  systemd = import ./systemd;

  types = import ./types.nix { inherit lib; };
}
