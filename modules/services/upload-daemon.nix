# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ pkgs, lib, config, ... }:
with lib;
let
  cfg = config.services.upload-daemon;
  description = "a daemon that asynchronously copies paths to a remote store";
in
{
  options.services.upload-daemon = with types; {
    enable = mkEnableOption description;
    target = mkOption {
      description = "A store to upload paths to";
      type = str;
    };
    port = mkOption {
      description = "Port to listen for paths to upload";
      type = nullOr port;
      default = null;
    };
    socket = mkOption {
      description = "UNIX socket to listen on";
      type = nullOr path;
      default = "/run/upload-daemon.sock";
    };
    prometheusPort = mkOption {
      description = "Port that prometheus endpoint listens on";
      type = nullOr port;
      default = 8082;
    };
    package = mkOption {
      description = "Package containing upload-daemon";
      type = package;
      default = pkgs.scratch-upload-daemon;
    };
  };
  config = mkIf cfg.enable {
    systemd.services.upload-daemon = {
      inherit description;
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [ nix ];
      script =
        ''${cfg.package}/bin/upload-daemon \
          --target "${cfg.target}" \
          ${lib.optionalString (! isNull cfg.port) "--port ${toString cfg.port}"} \
          ${lib.optionalString (! isNull cfg.socket) "--unix \"${toString cfg.socket}\""} \
          ${lib.optionalString (! isNull cfg.prometheusPort) "--stat-port ${toString cfg.prometheusPort}"} \
          -j $(nproc) \
          +RTS -N$(nproc)'';
      serviceConfig.Restart = "always";
    };
  };
}
