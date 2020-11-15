# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.virtualisation.podman.autoPrune;

in {
  options.virtualisation.podman.autoPrune = {
    users = mkOption {
      type = types.listOf types.str;
      default = [];
      example = [ "gitlab-runner" ];
      description = ''
        Users for which to run <command>podman system prune</command> regularly
      '';
    };

    flags = mkOption {
      type = types.listOf types.str;
      default = [];
      example = [ "--all" ];
      description = ''
        Any additional flags passed to <command>podman system prune</command>.
      '';
    };

    dates = mkOption {
      type = types.str;
      default = "weekly";
      description = ''
        Specification (in the format described by
        <citerefentry><refentrytitle>systemd.time</refentrytitle>
        <manvolnum>7</manvolnum></citerefentry>) of the time at
        which the prune will occur.
      '';
    };
  };

  config = {
    systemd.services = lib.mkMerge (flip builtins.map cfg.users (user: {
      "podman-prune-${user}" = {
        path = [ config.virtualisation.podman.package ];

        script = ''
          podman system prune --force ${toString cfg.flags}
        '';

        startAt = cfg.dates;

        serviceConfig = {
          Type = "oneshot";
          User = user;
        };
      };
    }));
  };
}
