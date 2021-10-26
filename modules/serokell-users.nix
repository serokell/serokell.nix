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

    wheelUsersExtraGroups = mkOption {
      default = [ ];
      type = types.listOf types.str;
      description = "Extra groups added to users in wheelUsers";
      example = [ "docker" ];
    };

    regularUsers = mkOption {
      default = [ ];
      type = types.listOf types.str;
      description = "Regular users";
      example = [ "misha" "vasya" "petya" ];
    };

    regularUsersExtraGroups = mkOption {
      default = [ ];
      type = types.listOf types.str;
      description = "Extra groups added to all users";
      example = [ "systemd-journal" ];
    };
  };

  config = {
    # default wheel users
    serokell-users.wheelUsers = [
      "kirelagin"
      "jaga"
      "sweater"
      "balsoft"
      "zhenya"
      "rvem"
      "notgne2"
      "cab404"
    ];

    # provision users and ssh keys
    users.users = lib.genAttrs allUsers (name: {
      isNormalUser = true;
      openssh.authorizedKeys.keys = ssh-keys.${name};
      extraGroups = cfg.regularUsersExtraGroups ++
        (lib.optionals (elem name cfg.wheelUsers) ([ "wheel" ] ++ cfg.wheelUsersExtraGroups));
    });

    # give all users access to systemd logs
    users.groups.systemd-journal.members = allUsers;

    # Allow users with sudo to modify the nix store
    nix.trustedUsers = [ "root" "@wheel" ];
  };
}
