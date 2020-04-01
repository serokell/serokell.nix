# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

let
  inherit (import ../../.) lib;
  pkgs = import (import ../../nix/sources.nix).nixpkgs { };

  testConfig = { pkgs, ...}: {
    environment.systemPackages = [ pkgs.git ];
  };
in

{
  testSystem = lib.nixos.buildSystem { config = testConfig; };
}
