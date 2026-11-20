# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ config, lib, modulesPath, options, ... }:
let
  cfg = config.serokell.systemd.restartPolicyWarnings;
  nativeServices = lib.genAttrs (lib.concatMap (definition:
    lib.optionals
      (lib.hasPrefix "${toString modulesPath}/" definition.file)
      (builtins.attrNames definition.value)
  ) options.systemd.services.definitionsWithLocations) (_: true);

  missingRestartPolicy = lib.filterAttrs (name: service:
    service.enable
    && !(builtins.hasAttr name nativeServices)
    && !(builtins.elem name cfg.exclude)
    && (service.serviceConfig.Type or "simple") != "oneshot"
    && (service.serviceConfig.Restart or "no") == "no"
  ) config.systemd.services;
in
{
  options.serokell.systemd.restartPolicyWarnings = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Warn when an enabled systemd service defined outside the NixOS modules
        has no restart policy. Oneshot services and services with a definition
        from the NixOS modules tree are exempt, including overridden services.
      '';
    };

    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "example" "worker@" ];
      description = ''
        Exact keys in systemd.services to exempt from restart policy warnings.
        Omit the .service suffix. To exempt a template and its instances, list
        the template and each instance separately.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    warnings = lib.mapAttrsToList (name: _:
      "Service '${name}.service' does not have a restart policy, please consider adding one."
    ) missingRestartPolicy;
  };
}
