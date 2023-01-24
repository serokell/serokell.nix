# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ config, lib, pkgs, ... }:
let
  cfg = config.serokell-users;
  allUsers = cfg.wheelUsers ++ cfg.regularUsers;
  ssh-keys = import ./ssh-keys.nix;
in
{
  options.serokell-users = import ./serokell-users-options.nix { inherit lib; };

  config = {
    # Allow users with sudo to modify the nix store
    nix.settings.trusted-users = [ "root" "@wheel" ];
  };
}
