{inputs}:{ config, pkgs, lib, ... }@args:

let
  wireguard-ip = config.wireguard-ip-address;
  common = import ./common.nix args;

  wg-fake = pkgs.buildGoModule {
    pname = "wg-fake";
    version = "0.0.1";
    vendorHash = "sha256-ciBIR+a1oaYH+H1PcC8cD8ncfJczk1IiJ8iYNM+R6aA=";
    src = inputs.wg-fake-src;
  };

in {
  inherit (common) options;

  config = {
    #networking.firewall.allowedUDPPorts = [
      #51820 # wireguard
    #];

    # firewall rules for the wireguard interface
    #networking.firewall.interfaces.wg0.allowedTCPPorts = [
      #9100 # prometheus node exporter
      #9256 # prometheus process exporter
    #];

    # enable wireguard
    networking.wg-quick.interfaces.wg0 = let
      listenPort = 51820;
    in {
      inherit listenPort;
      address = [ "${wireguard-ip}/16" ];
      preUp = "${wg-fake}/wg-fake -s ${common.polisPeer.endpoint} -p ${builtins.toString listenPort}";

      # (you have to generate it manually with `wg genkey > private_key`)
      privateKeyFile = "/etc/wireguard/secret";

      # set up link to polis
      peers = [ common.polisPeer ];
    };

    launchd.daemons.prometheus-node-exporter = {
      script = ''
        ${pkgs.prometheus-node-exporter}/bin/node_exporter --web.listen-address ${wireguard-ip}:9100
      '';
      serviceConfig = {
        ProcessType = "Interactive";
        ThrottleInterval = 30;
        RunAtLoad = true;
        UserName = "node-exporter";
        GroupName = "node-exporter";
        WorkingDirectory = "/var/lib/node-exporter";
        Umask = 63;
        StandardErrorPath = "/var/lib/node-exporter/err.log";
        StandardOutPath = "/var/lib/node-exporter/out.log";
      };
    };
    users = {
      users.node-exporter = {
        createHome = true;
        gid = 2059;
        uid = 2059;
        home = "/var/lib/node-exporter";
      };
      groups.node-exporter = {
        gid = 2059;
      };
      knownUsers = ["node-exporter"];
      knownGroups = ["node-exporter"];
    };

    # Run promtail and connect to our Loki instance
    #services.promtail = {
      #enable = true;
      #configuration = {
        #server = {
          #http_listen_port = 0;
          #grpc_listen_port = 0;
        #};
        #positions.filename = "/tmp/positions.yaml";
        #clients = [{
          #url = "http://172.21.0.1:3100/loki/api/v1/push";
        #}];
        #scrape_configs = [{
          #job_name = "journal";
          #journal = {
            #max_age = "12h";
            #labels = {
              #job = "systemd-journal";
              #host = config.networking.hostName;
            #};
          #};
          #relabel_configs = [{
            #source_labels = [ "__journal__systemd_unit" ];
            #target_label = "unit";
          #}];
        #}];
      #};
    #};
  };
}
