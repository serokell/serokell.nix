# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{
  edition = 201911;

  description = "Serokell Nix infrastructure library";

  outputs = { self, nixpkgs, gitignore }:
    let
      # rename
      gitignore0 = gitignore;
    in let
      pkgs = nixpkgs {};
      gitignore = gitignore0 {};
    in {
      overlay = import ./overlay { inherit pkgs; };
      lib = import ./lib { inherit pkgs gitignore; };
    };
}
