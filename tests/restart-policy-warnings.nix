# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ nixpkgs, pkgs, restartPolicyWarnings }:
let
  inherit (pkgs) lib;
  eval = enable: (nixpkgs.lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [
      restartPolicyWarnings
      {
        system.stateVersion = "26.05";
        serokell.systemd.restartPolicyWarnings = {
          inherit enable;
          exclude = [ "intentional" "excluded@" ];
        };
        systemd.services = {
          implicit = {};
          explicit.serviceConfig.Restart = "no";
          restarting.serviceConfig.Restart = "on-failure";
          once.serviceConfig.Type = "oneshot";
          disabled.enable = false;
          "worker@" = {};
          "worker@one" = {};
          intentional.serviceConfig.Restart = "no";
          "excluded@" = {};
          "excluded@one" = {};
          nix-daemon.serviceConfig.Restart = lib.mkForce "no";
        };
      }
      {
        _file = "generated-services.nix";
        systemd.services = lib.mkMerge (map (name: { ${name} = {}; }) [ "generated" ]);
      }
    ];
  }).config;

  warning = name: "Service '${name}.service' does not have a restart policy, please consider adding one.";
  restartWarnings = cfg: builtins.filter
    (lib.hasSuffix "does not have a restart policy, please consider adding one.") cfg.warnings;
  enabled = eval true;
  expected = map warning [ "excluded@one" "explicit" "generated" "implicit" "worker@" "worker@one" ];
in
assert lib.assertMsg (restartWarnings enabled == expected)
  "Unexpected restart policy warnings: ${builtins.toJSON (restartWarnings enabled)}";
assert lib.assertMsg (restartWarnings (eval false) == [])
  "Disabled restart policy checker emitted warnings";
assert lib.assertMsg (
  !(enabled.systemd.services.implicit.serviceConfig ? Restart)
  && enabled.systemd.services.explicit.serviceConfig.Restart == "no"
  && enabled.systemd.services.restarting.serviceConfig.Restart == "on-failure"
) "Restart policy checker changed a service restart policy";
pkgs.runCommand "restart-policy-warnings" {} "touch $out"
