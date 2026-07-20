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

    virtualisation.docker.logDriver = "journald";

    # Run Grafana Alloy and connect to our Loki instance
    services.alloy.enable = true;

    environment.etc."alloy/config.alloy".text = ''
      // Loki endpoint all sources forward to
      loki.write "loki" {
        endpoint {
          url = "http://172.21.0.1:3100/loki/api/v1/push"
        }
      }

      // Relabeling applied to the systemd journal
      loki.relabel "journal" {
        forward_to = []

        rule {
          source_labels = ["__journal__uid"]
          target_label  = "user_id"
        }

        // some explanation to the next two rules.
        // Important to notice that both have the same target_label: unit.
        // if we would use only one rule with 2 source_labels, unfortunately only those
        // labels will be kept where we have both source labels, so the root level services's log entries are gone.
        // Regaring the 2nd rule's regex: "(.*);(.+)", we want to match only those where the __journal__systemd_user_unit
        // is not empty, the regex matches and replaces the label with our $2 value which is the value of __journal__systemd_user_unit.
        rule {
          source_labels = ["__journal__systemd_unit"]
          target_label  = "unit"
        }

        rule {
          source_labels = ["__journal__systemd_unit", "__journal__systemd_user_unit"]
          target_label  = "unit"
          regex         = "(.*);(.+)"
          replacement   = "$2"
        }
      ${lib.optionalString config.virtualisation.docker.enable ''
        rule {
          source_labels = ["__journal_container_name"]
          target_label  = "container"
        }
      ''}}

      loki.source.journal "journal" {
        max_age       = "12h"
        labels        = {
          job  = "systemd-journal",
          host = "${config.networking.hostName}",
        }
        relabel_rules = loki.relabel.journal.rules
        forward_to    = [loki.write.loki.receiver]
      }
      ${lib.optionalString config.services.nginx.enable ''

      local.file_match "nginx_error" {
        path_targets = [{
          __path__ = "/var/log/nginx/*error.log",
          job      = "nginx-error-logs",
          host     = "${config.networking.hostName}",
        }]
      }

      loki.source.file "nginx_error" {
        targets    = local.file_match.nginx_error.targets
        forward_to = [loki.write.loki.receiver]
      }
      ''}'';

    # Allow Alloy (runs as a DynamicUser, already in the systemd-journal group)
    # to read nginx error logs.
    systemd.services.alloy.serviceConfig.SupplementaryGroups =
      lib.mkIf config.services.nginx.enable [ "nginx" ];

    # wait for wireguard before starting node-exporter
    systemd.services.prometheus-node-exporter.after = [ "wireguard-wg0.service" ];
  };
}
