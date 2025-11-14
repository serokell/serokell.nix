# SPDX-FileCopyrightText: 2025 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.serokell.restartPolicyWarning;

  upstreamRoots = [ (toString pkgs.path) ] ++ cfg.upstreamRoots;

  svcFor = name: builtins.getAttr name config.systemd.services;

  # Extract provenance paths from service metadata
  originPathsFor = name:
    let
      svc = svcFor name;
      m = (svc._module or {});
      toPath = d:
        if builtins.typeOf d == "string"
        then lib.head (lib.splitString ":" d)
        else if builtins.isAttrs d && d ? file
        then toString d.file
        else toString d;
    in
      (map toPath (m.files or [])) ++ (map toPath (m.declarations or []));

  # Check if any path has a prefix in the given list
  fromAnyPrefix = paths: prefixes:
    lib.any (p: lib.any (pref: lib.hasPrefix (toString pref) (toString p)) prefixes) paths;

  isFromUpstream = name: fromAnyPrefix (originPathsFor name) upstreamRoots;
  
  isFromMyModules = name:
    cfg.moduleRoots != [] && fromAnyPrefix (originPathsFor name) cfg.moduleRoots;

  hasUnknownProvenance = name: (originPathsFor name) == [];

  isInExtraPrefixes = name:
    lib.any (prefix: lib.hasPrefix prefix name) cfg.extraPrefixes;

  isIgnored = name:
    lib.elem name cfg.ignore;

  # Determine if a service is in scope for warnings
  inScope = name:
    if cfg.moduleRoots != []
    then isFromMyModules name
    else true;

  # Determine if a service is external (should be warned about)
  isExternal = name:
    if cfg.moduleRoots != []
    then
      # If moduleRoots specified, only warn about services from those modules
      isFromMyModules name
    else
      # Otherwise, warn about services that are known and not from upstream
      # (conservative: don't warn if provenance is unknown)
      (!hasUnknownProvenance name) && (!isFromUpstream name);

  needsRestartWarning = name:
    let
      svc = svcFor name;
      restart = svc.serviceConfig.Restart or "no";
      type = svc.serviceConfig.Type or "";
    in
      cfg.enable
      && inScope name
      && (cfg.warnIfUnknown || !hasUnknownProvenance name)
      && isExternal name
      && !(isInExtraPrefixes name)
      && !(isIgnored name)
      && restart == "no"
      && type != "oneshot";

  warningMessages = lib.concatMap (name:
    lib.optional (needsRestartWarning name)
      "Service '${name}.service' does not have a restart policy, please consider adding one."
  ) (builtins.attrNames config.systemd.services);

in
{
  options.serokell.restartPolicyWarning = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable warnings for systemd services without restart policies.
        
        This module warns about systemd services that don't have an explicit
        restart policy configured. It uses the module system's provenance
        metadata to determine which services come from upstream (nixpkgs) and
        which are external/custom.
        
        By default, it only warns about services with known provenance that
        are not from upstream. Services with unknown provenance are skipped
        to avoid false positives.
      '';
    };

    upstreamRoots = mkOption {
      type = types.listOf types.str;
      default = [];
      example = [ "/path/to/other/nixpkgs" ];
      description = ''
        Additional upstream root paths to consider when determining if a
        service comes from upstream.
        
        The nixpkgs path (pkgs.path) is automatically included, so you only
        need to add this option if you have additional upstream sources.
      '';
    };

    moduleRoots = mkOption {
      type = types.listOf types.str;
      default = [ (toString (lib.dirOf ./.)) ];
      example = [ "/path/to/my/modules" ];
      description = ''
        Path prefixes for modules to check. By default, automatically set to
        the repository containing this module (serokell.nix), so warnings only
        apply to services defined in this repository's modules.
        
        Set to [] to check all non-upstream services with known provenance
        instead of scoping to specific module directories.
        
        Add additional paths to include services from other module repositories.
      '';
    };

    warnIfUnknown = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If true, warn about services even when provenance cannot be determined.
        
        By default (false), services with unknown provenance are skipped to
        avoid false positives. Enable this only if you want to be notified
        about all services without restart policies, regardless of origin.
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

  config = mkIf (cfg.enable && lib.hasAttrByPath [ "systemd" "services" ] config) {
    warnings = warningMessages;
  };
}
