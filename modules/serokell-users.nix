# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.serokell-users;
  allUsers = cfg.wheelUsers ++ cfg.regularUsers;
  ssh-keys = import ./ssh-keys.nix;

in
{
  options.serokell-users = {
    wheelUsers = mkOption {
      type = types.listOf types.str;
      description = "Users added to wheel group";
      example = [ "gosha" "masha" ];
    };

    regularUsers = mkOption {
      default = [ ];
      type = types.listOf types.str;
      description = "Regular users";
      example = [ "misha" "vasya" "petya" ];
    };
  };

  config = {
    # default wheel users
    serokell-users.wheelUsers = [
      "chris"
      "kirelagin"
      "jaga"
      "sweater"
      "balsoft"
      "zhenya"
      "rvem"
      "notgne2"
    ];

    # provision users and ssh keys
    users.users = lib.genAttrs allUsers (name: {
      isNormalUser = true;
      openssh.authorizedKeys.keys = ssh-keys.${name};
      extraGroups = lib.optionals (elem name cfg.wheelUsers) [ "wheel" ];
    });

    # give all users access to systemd logs
    users.groups.systemd-journal.members = allUsers;

    # Allow users with sudo to modify the nix store
    nix.trustedUsers = [ "root" "@wheel" ];
  };
}
