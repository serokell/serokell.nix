# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.matomo;
in

{
  disabledModules = [ "services/web-apps/matomo.nix" ];

  imports = [
    (mkRemovedOptionModule [ "services" "matomo" "nginx" ] "")
    (mkRemovedOptionModule [ "services" "matomo" "phpfpmProcessManagerConfig" ] "")
    (mkRemovedOptionModule [ "services" "matomo" "webServerUser" ] "")
  ];

  options = {
    services.matomo = {
      enable = mkEnableOption "Matomo web analytics";

      dataDir = mkOption {
        default = "/var/lib/matomo";
        type = types.path;
      };

      package = mkOption {
        default = pkgs.matomo;
        type = types.package;
      };

      virtualHost = mkOption {
        default = "matomo";
        type = types.str;
      };
    };
  };

  config = mkIf cfg.enable {
    users.users.matomo = {
      isSystemUser = true;
      createHome = true;
      home = cfg.dataDir;
      group = "matomo";
    };

    services.mysql = {
      enable = true;
      ensureDatabases = [ "matomo" ];
      ensureUsers = [{
        name = "matomo";
        ensurePermissions = { "matomo.*" = "ALL PRIVILEGES"; };
      }];
    };

    users.groups.matomo = {};

    systemd.services.matomo-setup = {
      after = [ "mysql.service" ];
      before = [ "phpfpm-matomo.service" ];
      requires = [ "mysql.service" ];

      path = [ cfg.package ];
      environment.PIWIK_USER_PATH = cfg.dataDir;
      serviceConfig = {
        PermissionsStartOnly = true;
        Type = "oneshot";
        UMask = "0007"; # hide config.ini.php
        User = "matomo";
      };

      preStart = "chown -R matomo:matomo ${cfg.dataDir}";

      script = ''
        if test -f "${cfg.dataDir}/config/config.ini.php"; then
          matomo-console core:update --yes
        fi
      '';
    };

    systemd.services.phpfpm-matomo = {
      # Stop phpfpm pool on package upgrade:
      restartTriggers = [ cfg.package ];
      requires = [ "matomo-setup.service" ];
      # Make sure that config.ini.php is only readable by matomo user:
      serviceConfig.UMask = "0007";
    };

    services.phpfpm.pools.matomo = {
      listen = "/run/phpfpm-matomo.sock";
      extraConfig = ''
        listen.owner = ${config.services.nginx.user}
        listen.group = ${config.services.nginx.group}
        listen.mode = 0600
        user = matomo
        env[PIWIK_USER_PATH] = ${cfg.dataDir}
        pm = dynamic
        pm.max_children = 75
        pm.start_servers = 10
        pm.min_spare_servers = 5
        pm.max_spare_servers = 20
        pm.max_requests = 500
      '';
    };

    services.nginx.virtualHosts = mkIf (cfg.virtualHost != null) {
      "${cfg.virtualHost}" = {
        root = "${cfg.package}/share";

        locations = {
          "/".index = "index.php";

          "= /index.php".extraConfig = ''
            fastcgi_pass unix:${config.services.phpfpm.pools.matomo.listen};
          '';

          "= /piwik.php".extraConfig = ''
            fastcgi_pass unix:${config.services.phpfpm.pools.matomo.listen};
          '';

          "~* ^.+\.php$".extraConfig = ''
            return 403;
          '';
        };
      };
    };
  };
}
