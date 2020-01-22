# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

#
# nix-flakes shim
#

let
  sources
    = builtins.removeAttrs (import ./nix/sources.nix) ["__functor"]
    ;

  inputs = builtins.mapAttrs (_: s: import s) sources;
  flake = (import ./flake.nix).outputs (inputs // { self = flake; });
in

flake
