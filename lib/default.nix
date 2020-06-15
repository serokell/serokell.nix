# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ lib, gitignore-nix }:

{
  src = import ./src.nix { inherit lib gitignore-nix; };
}
