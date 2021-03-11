
# SPDX-FileCopyrightText: 2021 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ config, lib, pkgs, ... }:

let
  cfg = config.nix.gc;

in {
  options.nix.gc.keep-gb = lib.mkOption {
    type = lib.types.int;
    description = "Amount of free space (in GB) to keep on the disk by running garbage collection";
    default = 15;
  };

  config = {
    nix.gc = {
      automatic = true;

      # delete so there is ${keep-gb} GB free, and delete very old generations
      # delete-older-than by itself will still delete all non-referenced packages (ie build dependencies)
      options =
        let
          cur-avail-cmd = "df -P -k /nix/store | tail -n 1 | ${pkgs.gawk}/bin/awk '{ print $4 }'";
          # free `${keep-gb} - ${cur-avail}` of space
          max-freed-expression = "${toString cfg.keep-gb} * 1024**3 - 1024 * $(${cur-avail-cmd})";
        in lib.mkDefault ''--delete-older-than 14d --max-freed "$((${max-freed-expression}))"'';
    };
  };
}
