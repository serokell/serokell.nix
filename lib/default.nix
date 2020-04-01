# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ pkgs, haskell-nix }:

{
  src = import ./src.nix { inherit haskell-nix; };
  nixos = import ./nixos.nix { inherit pkgs; };
}
