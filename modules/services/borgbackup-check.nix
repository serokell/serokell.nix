# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.borgbackup;

  # Helper function to determine if a path is local
  isLocalPath =
    x:
    builtins.substring 0 1 x == "/" # absolute path
    || builtins.substring 0 1 x == "." # relative path
    || builtins.match "[.*:.*]" x == null; # not machine:path

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
  options = {
    services.borgbackup.jobs = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          enableCheck = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Whether to enable weekly repository checks for this borgbackup job.
              This creates a systemd service and timer that runs 'borg check' weekly.
            '';
          };
        };
      });
    };
  };

  config = mkIf (cfg.jobs != {}) {
    systemd.services = mapAttrs' mkCheckService (
      filterAttrs (name: jobCfg: jobCfg.enableCheck or true) cfg.jobs
    );
  };
}
