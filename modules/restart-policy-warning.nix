# SPDX-FileCopyrightText: 2025 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ config, lib, pkgs, options, ... }:

with lib;

let
  cfg = config.serokell.restartPolicyWarning;

  nixpkgsPath = toString pkgs.path;

  serviceNames = builtins.attrNames config.systemd.services;

  declPathsFor = name:
    let
      opt = lib.getAttrFromPath ["systemd" "services" name] options;
      decls = opt.declarations or [];
    in map (d:
      if builtins.typeOf d == "string"
      then lib.head (lib.splitString ":" d)
      else if builtins.isAttrs d && d ? file
      then d.file
      else toString d
    ) decls;

  isFromNixpkgs = name:
    let paths = declPathsFor name;
    in lib.any (p: lib.hasPrefix nixpkgsPath (toString p)) paths;

  isInExtraPrefixes = name:
    lib.any (prefix: lib.hasPrefix prefix name) cfg.extraPrefixes;

  isIgnored = name:
    lib.elem name cfg.ignore;

  isExternalService = name:
    !(isFromNixpkgs name) && !(isInExtraPrefixes name) && !(isIgnored name);

  needsRestartWarning = name:
    let
      service = config.systemd.services.${name};
      restart = service.serviceConfig.Restart or "no";
      type = service.serviceConfig.Type or "";
    in
      cfg.enable
      && isExternalService name
      && restart == "no"
      && type != "oneshot";

  warningMessages = lib.concatMap (name:
    lib.optional (needsRestartWarning name)
      "Service '${name}.service' does not have a restart policy, please consider adding one."
  ) serviceNames;

in
{
  options.serokell.restartPolicyWarning = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable warnings for systemd services without restart policies.
        
        This module warns about custom (non-nixpkgs) systemd services that
        don't have an explicit restart policy configured. It uses the module
        system's provenance metadata to determine which services come from
        nixpkgs and which are external/custom.
      '';
    };

    extraPrefixes = mkOption {
      type = types.listOf types.str;
      default = [
        "network-"
        "nix-optimise"
        "mount-pstore"
        "wireguard-"
        "acme-"
        "mdmonitor"
        "iodined"
        "restic-backups-"
        "borgbackup-"
      ];
      description = ''
        Additional service name prefixes to exclude from warnings.
        These are typically dynamic or templated service names from nixpkgs.
      '';
    };

    ignore = mkOption {
      type = types.listOf types.str;
      default = [];
      example = [ "my-oneshot-service" "legacy-service" ];
      description = ''
        List of specific service names to exclude from restart policy warnings.
        Use this for services that legitimately don't need restart policies.
      '';
    };
  };

  config = mkIf cfg.enable {
    warnings = warningMessages;
  };
}
