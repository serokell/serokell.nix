# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ lib, gitignore-nix }:

rec {
  src = import ./src.nix { inherit lib gitignore-nix; };

  # Extend nixpkgs with multiple overlays
  #   pkgs = pkgsWith nixpkgs.legacyPackages.${system} [ inputs.serokell-nix.overlay ];
  foldExtensions = builtins.foldl' lib.composeExtensions (_: _: { });
  pkgsWith = p: e: p.extend (foldExtensions e);

  types = import ./types.nix { inherit lib; };
}
