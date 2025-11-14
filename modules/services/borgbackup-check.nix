# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.borgbackup;

  # Helper function to determine if a path is local
  # Local if it starts with "/" or "." and doesn't contain ":"
  isLocalPath =
    x:
    (builtins.substring 0 1 x == "/" || builtins.substring 0 1 x == ".")
    && !(lib.hasInfix ":" x);

  # Helper function to create password environment variables
  mkPassEnv =
    jobCfg:
    with jobCfg.encryption;
    if passCommand != null then
      { BORG_PASSCOMMAND = passCommand; }
    else if passphrase != null then
      { BORG_PASSPHRASE = passphrase; }
    else
      { };

  # Create a check service for a borgbackup job
  mkCheckService = name: jobCfg: nameValuePair "borgbackup-check-${name}" (rec {
    description = "Check BorgBackup repository ${name}";
    after = [ "borgbackup-job-${name}.service" ];
    conflicts = after;
    path = with pkgs; [ borgbackup openssh ];
    serviceConfig = {
      User = jobCfg.user;
      Group = jobCfg.group;
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";
      ReadWritePaths = mkIf (isLocalPath jobCfg.repo) [ jobCfg.repo ];
      ExecStart = "${pkgs.borgbackup}/bin/borg check";
    };
    environment = {
      BORG_REPO = jobCfg.repo;
    } // (mkPassEnv jobCfg) // jobCfg.environment;
    startAt = "weekly";
  });

in

{
  config = mkIf (cfg.jobs != {}) {
    systemd.services = mapAttrs' mkCheckService cfg.jobs;
  };
}
