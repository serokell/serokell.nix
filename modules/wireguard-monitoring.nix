{ config, pkgs, lib, ... }:

let
  wireguard-ip = config.wireguard-ip-address;

in {
  options = {
    wireguard-ip-address = lib.mkOption {
      type = lib.types.str;
      description = "IP address for the wireguard interface (in the 172.21.0.0/16 subnet)";
      example = "172.21.0.3";
    };
    wireguard-allowed-ips = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "AllowedIPs list";
      default = [ "172.21.0.1/32" ];
    };
  };

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
      peers = [{
        allowedIPs = config.wireguard-allowed-ips;
        endpoint = "polis.sagittarius.serokell.team:51820";
        publicKey = "gOS8bfFuFJmEpaZa19i2Q62gKAaTyL+XWCJvmxekqy8=";
      }];
    };

    # run process-exporter on the wireguard interface
    services.prometheus.exporters.process.listenAddress = wireguard-ip;

    # run node-exporter on the wireguard interface
    services.prometheus.exporters.node.listenAddress = wireguard-ip;

    # Run promtail and connect to our Loki instance
    services.promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = 0;
          grpc_listen_port = 0;
        };
        positions.filename = "/tmp/positions.yaml";
        clients = [{
          url = "http://172.21.0.1:3100/loki/api/v1/push";
        }];
        scrape_configs = [{
          job_name = "journal";
          journal = {
            max_age = "12h";
            labels = {
              job = "systemd-journal";
              host = config.networking.hostName;
            };
          };
          relabel_configs = [{
            source_labels = [ "__journal__systemd_unit" ];
            target_label = "unit";
          }];
        }];
      };
    };

    # wait for wireguard before starting node-exporter
    systemd.services.prometheus-node-exporter.after = [ "wireguard-wg0.service" ];
  };
}
