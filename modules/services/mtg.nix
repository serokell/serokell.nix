{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkOption mkEnableOption;
  inherit (builtins) toString;
  cfg = config.services.mtg;
in
{
  options.services.mtg = with lib; {
    enable = mkEnableOption "mtg, alternative MTProto Proxy";

    package = mkOption {
      type = types.package;
      defaultText = "pkgs.mtg";
      default = pkgs.mtg;
      description = ''
        Package to use for the service.
      '';
    };

    localPort = mkOption {
      type = types.int;
      default = 9999;
      example = 8888;
      description = ''
        Local port to get usage stats from. Only works via loopback.
      '';
    };

    httpPort = mkOption {
      type = types.int;
      default = 3128;
      example = 3000;
      description = ''
        HTTP port for clients to connect to.
      '';
    };

    secretFile = mkOption {
      type = types.path;
      description = ''
        A path to a secret file. Should contain the proxy's secret.
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.services.mtg = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      description = "mtg MTProto proxy server for Telegram.";

      script = ''
        ${cfg.package}/bin/mtg run \
        -b 0.0.0.0:${toString cfg.httpPort} \
        -t 127.0.0.1:${toString cfg.localPort} \
        "$(cat ${cfg.secretFile})"
      '';

      serviceConfig = {
        DynamicUser = true;
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.httpPort ];
  };
}
