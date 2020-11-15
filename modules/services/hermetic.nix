# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.hermetic;
in

{
  options = {
    services.hermetic = {
      enable = mkEnableOption "Hermetic Slack bot for YouTrack";

      package = mkOption {
        default = pkgs.hermetic;
        defaultText = "pkgs.hermetic";
        type = types.package;
      };

      environmentFile = mkOption {
        default = null;
        type = with types; nullOr path;
      };

      virtualHost = mkOption {
        default = "hermetic";
        type = types.nullOr types.str;
      };

      port = mkOption {
        default = 59468;
        type = types.int;
      };
    };
  };

  config = mkIf cfg.enable {
    services.epmd.enable = true;

    services.nginx.virtualHosts = mkIf (cfg.virtualHost != null) {
      "${cfg.virtualHost}".locations."/".proxyPass =
        "http://127.0.0.1:${toString cfg.port}";
    };

    systemd.services.hermetic = rec {
      wantedBy = [ "multi-user.target" ];
      requires = [ "epmd.service" "network.target" ];
      after = requires;
      path = with pkgs; [ elixir ];

      environment = {
        HOME = "/tmp";
        RELEASE_TMP = "/tmp";
        RELEASE_NODE = "hermetic@127.0.0.1";
        RELEASE_DISTRIBUTION = "name";
        HERMETIC_PORT = "${toString cfg.port}";
      };

      script = ''
        export RELEASE_COOKIE=$(head -c24 /dev/urandom | base64)
        ${cfg.package}/bin/hermetic start
      '';

      serviceConfig = {
        EnvironmentFile = optional (cfg.environmentFile != null) cfg.environmentFile;
        DynamicUser = true;
        WorkingDirectory = cfg.package;
        Restart = "on-failure";
        RestartSec = "1min";
      };
    };
  };
}
