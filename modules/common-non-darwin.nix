# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

# configuration options that do not exist for nix-darwin
{ lib, pkgs, config, options, ... }:
{
  imports = [
    ./services/nginx.nix
  ];

  options.services.nginx.addSecurityHeaders = lib.mkOption {
    description = "whether to add security headers to all nginx virtualHosts";
    type = lib.types.bool;
    default = true;
  };

  config = {

    # Default to /tmp on disk, move it to tmpfs if server big enough
    boot.tmp.cleanOnBoot = true;
    documentation.nixos.enable = false;

    programs.mosh.enable = true;

    programs.atop.enable = false;

    security.acme = {
      defaults.email = "operations@serokell.io";
      acceptTerms = true;
    };

    services.earlyoom.enable = lib.mkDefault true;
    services.mysql.package = lib.mkOptionDefault pkgs.mariadb;
    services.postgresql.package = lib.mkOptionDefault pkgs.postgresql_12;

    security.sudo.wheelNeedsPassword = false;

    services.openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
      ports = [ 17788 ];
    };

    users.mutableUsers = false;

    services.prometheus.exporters.process = {
      enable = true;
      settings.process_names = [
        {
          name = "{{ .Matches.Wrapped }}";
          cmdline = [ "^/nix/store[^ ]*/(?P<Wrapped>[^ /]*)" ];
        }
        {
          name = "{{ .Matches.Command }}";
          cmdline = [ "(?P<Command>[^ ]+)" ];
        }
      ];
    };

    services.prometheus.exporters.node = {
      enable = true;
      enabledCollectors = [ "systemd" ];
      extraFlags = [ "--collector.systemd.enable-restarts-metrics" ];
      disabledCollectors = [ "timex" ];
    };

    services.nginx = {
      package = pkgs.nginxStable.override {
        modules = with pkgs.nginxModules; [ brotli ];
      };
      appendHttpConfig = ''
        if_modified_since off;
      '';
      recommendedGzipSettings = lib.mkDefault true;
      recommendedOptimisation = lib.mkDefault true;
      recommendedProxySettings = lib.mkDefault true;
      recommendedTlsSettings = lib.mkDefault true;
      commonHttpConfig = lib.mkIf config.services.nginx.addSecurityHeaders ''
        # Add HSTS header with preloading to HTTPS requests.
        # Adding this header to HTTP requests is discouraged
        map $scheme $hsts_header {
        https   "max-age=31536000; includeSubdomains; preload";
        }
        add_header Strict-Transport-Security $hsts_header;

        # Minimize information leaked to other domains
        add_header 'Referrer-Policy' 'strict-origin-when-cross-origin';

        # Disable embedding as a frame
        add_header X-Frame-Options DENY;

        # Prevent injection of code in other mime types (XSS Attacks)
        add_header X-Content-Type-Options nosniff;
      '';
    };

    # veth* are created by docker and don't require DHCP. Disabling it also
    # avoids issues with EC2 instances, because otherwise dhcpcd creates 169.254.0.0/16
    # route, which breaks access to AWS metadata and AWS NTP server.
    # nixpkgs issue: https://github.com/NixOS/nixpkgs/issues/109387
    networking.dhcpcd.denyInterfaces = [ "veth*" ];

    networking.firewall = {
      allowPing = false;
      logRefusedConnections = false;
    };

    # This value determines the NixOS release with which your system is to be
    # compatible, in order to avoid breaking some software such as database
    # servers. You should change this only after NixOS release notes say you
    # should.
    system.stateVersion = "20.03"; # Did you read the comment?
  };
}
