# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

#
# nix-flakes shim
#

let
  sources = builtins.removeAttrs (import ./nix/sources.nix) ["__functor"];

  flake = import sources.flake-compat { src = ./.; };
in
flake.defaultNix
