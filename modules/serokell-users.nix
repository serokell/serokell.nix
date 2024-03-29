# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ config, lib, pkgs, ... }:
let
  cfg = config.serokell-users;
  allUsers = cfg.wheelUsers ++ cfg.regularUsers;
  ssh-keys = import ./ssh-keys.nix;
  inherit (lib) optionals elem;
in
{
  options.serokell-users = import ./serokell-users-options.nix { inherit lib; };

  config = {
    # provision users and ssh keys
    users.users = lib.genAttrs allUsers (name: {
      isNormalUser = true;
      openssh.authorizedKeys.keys = ssh-keys.${name};
      extraGroups = cfg.regularUsersExtraGroups ++
        (optionals (elem name cfg.wheelUsers) ([ "wheel" ] ++ cfg.wheelUsersExtraGroups));
    });

    # give all users access to systemd logs
    users.groups.systemd-journal.members = allUsers;

    # Allow users with sudo to modify the nix store
    nix.settings.trusted-users = [ "root" "@wheel" ];
  };
}
