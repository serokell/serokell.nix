# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ config, lib, pkgs, ... }: {
  options.services.hackage-search = {
    enable = lib.mkEnableOption "Hackage search server";
    port = lib.mkOption {
      description = "A port for running hackage search server on";
      type = lib.types.nullOr lib.types.port;
      default = null;
    };
    socket = lib.mkOption {
      description = "Unix domain socket to serve the server on";
      type = lib.types.nullOr lib.types.str;
      default = "/run/hackage-search/server.sock";
    };
    package = lib.mkOption {
      description = "A hackage-search package";
      type = lib.types.str;
      # Updated from https://github.com/serokell/hackage-search/tree/release by buildkite pipeline
      default = "/nix/var/nix/profiles/per-user/buildkite-agent-public/hackage-search";
    };
  };
  config = let cfg = config.services.hackage-search; in lib.mkIf (cfg.enable) {
    systemd.timers = {
      hackage-download = {
        timerConfig = {
          OnCalendar = "daily";
        };
        wantedBy = [ "timers.target" ];
      };
    };
    systemd.services = {
      hackage-download = rec {
        requires = [ "network-online.target" ];
        after = requires;

        path = [ cfg.package ];

        script = ''hackage-download --hackage "$CACHE_DIRECTORY"'';

        serviceConfig = {
          DynamicUser = true;
          User = "hackage-search";

          CacheDirectory = "hackage-search";
          WorkingDirectory = "/var/cache/hackage-search";
          Type = "oneshot";
        };
      };
      hackage-search = with cfg; rec {
        wantedBy = [ "multi-user.target" ];

        requires = [ "hackage-download.service" ];
        after = requires;

        path = [ pkgs.ripgrep cfg.package ];

        # One and only one of port, socket is not-null
        script = assert isNull socket != isNull port;
        let serve = if ! isNull socket then "--unix ${socket}" else "--port ${toString port}"; in
        ''
          hackage-search ${serve} --frontend "${cfg.package}/html" --hackage "$CACHE_DIRECTORY"
        '';

        serviceConfig = {
          DynamicUser = true;
          User = "hackage-search";

          ExecStartPost = if isNull socket then null else pkgs.writeShellScript "chmod-socket" "sleep 5; chmod 777 ${socket}";

          CacheDirectory = "hackage-search";
          RuntimeDirectory = if isNull socket then null else "hackage-search";
        };
      };
    };
    services.nginx.virtualHosts.hackage-search = {
      serverName = "hackage-search.serokell.io";
      locations."/".proxyPass = if ! isNull cfg.socket then "http://unix:${cfg.socket}:/" else "http://localhost:${toString cfg.port}/";
      locations."/static/fonts/".root = "/var/lib/buildkite-agent-private/cd/serokell-website-production/out/website/";
    };
  };
}
