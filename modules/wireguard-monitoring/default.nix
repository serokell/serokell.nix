{ config, pkgs, lib, ... }@args:

let
  wireguard-ip = config.wireguard-ip-address;
  common = import ./common.nix args;
in {
  inherit (common) options;

  config = {
    networking.firewall.allowedUDPPorts = [
      51820 # wireguard
    ];

    # firewall rules for the wireguard interface
    networking.firewall.interfaces.wg0.allowedTCPPorts = [
      9100 # prometheus node exporter
      9256 # prometheus process exporter
    ];

    # enable wireguard
    networking.wireguard.interfaces.wg0 = {
      listenPort = 51820;
      ips = [ "${wireguard-ip}/16" ];

      # generate private key if it does not exist
      # (you can also generate it manually with `wg genkey > private_key`)
      generatePrivateKeyFile = true;
      privateKeyFile = "/etc/wireguard/secret";

      # set up link to polis
      peers = [ common.polisPeer ];
    };

    # run process-exporter on the wireguard interface
    services.prometheus.exporters.process.listenAddress = wireguard-ip;

    # run node-exporter on the wireguard interface
    services.prometheus.exporters.node.listenAddress = wireguard-ip;

    # Run Grafana Alloy and connect to our Loki instance
    services.alloy = {
      enable = true;
      extraFlags = [ "--storage.path=/var/lib/alloy" ];

      configPath = "/etc/alloy/config.alloy";
    };

    environment.etc."alloy/config.alloy".text = ''
        loki.write "loki" {
          endpoint {
            url = "http://172.21.0.1:3100/loki/api/v1/push"
          }

          external_labels = {}
        }

        loki.relabel "journal" {
          forward_to = [loki.write.loki.receiver]

          rule {
            source_labels = ["__journal__uid"]
            target_label  = "user_id"
          }

          rule {
            source_labels = ["__journal__systemd_unit"]
            target_label  = "unit"
          }

          // Override unit with systemd user unit when present
          rule {
            source_labels = ["__journal__systemd_unit", "__journal__systemd_user_unit"]
            target_label  = "unit"
            regex         = "(.*);(.+)"
            replacement   = "$2"
          }
          rule {
            source_labels = ["__journal_container_name"]
            target_label  = "container"
          }
        }

        loki.source.journal "journal" {
          max_age = "12h"

          labels = {
            job  = "systemd-journal",
            host = "${config.networking.hostName}",
          }

          forward_to = [loki.relabel.journal.receiver]
        }

      ${lib.optionalString config.services.nginx.enable ''
        loki.source.file "nginx_error_logs" {
          targets = [{
            __path__ = "/var/log/nginx/*error.log",
            job      = "nginx-error-logs",
            host     = "${config.networking.hostName}",
          }]

          forward_to = [loki.write.loki.receiver]
        }
      ''}
    '';

    # Add alloy user to nginx group for reading nginx error logs
    users.groups.nginx.members = lib.mkIf config.services.nginx.enable [ "alloy" ];

    # wait for wireguard before starting node-exporter
    systemd.services.prometheus-node-exporter.after = [ "wireguard-wg0.service" ];
  };
}
