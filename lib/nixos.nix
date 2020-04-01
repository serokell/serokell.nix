# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

###
# Utilities for configuring and building NixOS
###

{ pkgs }:

rec {
  # Evaluate a NixOS configuration.
  #
  # config: NixOS configuration.
  # modules: extra modules to add
  buildSystem = { config, modules ? [ defaults ] }:
    let
      c = import (pkgs.path + "/nixos/lib/eval-config.nix") {
        modules = modules ++ [ config ];
      };
    in c.config.system.build.toplevel;

  # A module with reasonable NixOS configuration defaults.
  # Note that you don’t need to pass any arguments to it.
  defaults = { pkgs, lib, ... }: {
    nixpkgs.localSystem.system = "x86_64-linux";

    documentation.nixos.enable = false;

    nix = {
      # https://github.com/NixOS/nix/issues/1964
      extraOptions = ''
        tarball-ttl = 0
      '';

      autoOptimiseStore = true;
      gc = {
        automatic = true;
        # delete so there is 15GB free, and delete very old generations
        # delete-older-than by itself will still delete all non-referenced packages (ie build dependencies)
        options = lib.mkForce ''
          --max-freed "$((15 * 1024**3 - 1024 * $(df -P -k /nix/store | tail -n 1 | ${pkgs.gawk}/bin/awk '{ print $4 }')))" --delete-older-than 14d'';
      };
    };

    services.openssh = {
      enable = true;
      passwordAuthentication = false;
    };

    environment.systemPackages = with pkgs; [ htop vim ];

    # Fake bootloader config, because many systems don’t need it.
    boot.loader.systemd-boot.enable = lib.mkDefault true;
    fileSystems."/" = lib.mkDefault {
      device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
      fsType = "btrfs";
    };
  };
}
