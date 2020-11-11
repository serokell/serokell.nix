# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ lib, pkgs, config, ... }:

{
  imports = [ ./nginx-vhosts.nix ];

  networking.firewall = {
    allowPing = false;
    logRefusedConnections = false;
  };

  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" ];
    disabledCollectors = [ "timex" ];
  };

  nix.autoOptimiseStore = true;

  # Use Jupiter as binary substituter
  nix.binaryCaches =
    [ "https://cache.nixos.org" ]; # "http://172.20.0.19:5000" ];
  nix.binaryCachePublicKeys =
    [ "serokell-1:aIojg2Vxgv7MkzPJoftOO/I8HKX622sT+c0fjnZBLj0=" ];

  # https://github.com/NixOS/nix/issues/1964
  nix.extraOptions = ''
    tarball-ttl = 0
  '';

  nix.gc = {
    automatic = true;
    # delete so there is 15GB free, and delete very old generations
    # delete-older-than by itself will still delete all non-referenced packages (ie build dependencies)
    options = lib.mkForce ''
      --max-freed "$((15 * 1024**3 - 1024 * $(df -P -k /nix/store | tail -n 1 | ${pkgs.gawk}/bin/awk '{ print $4 }')))" --delete-older-than 14d'';
  };

  programs.mosh.enable = true;

  # TODO: setup Bastion server
  security.sudo.wheelNeedsPassword = false;

  services.nginx = {
    appendHttpConfig = ''
      if_modified_since off;
      proxy_set_header        Host $host;
      proxy_set_header        X-Real-IP $remote_addr;
      proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header        X-Forwarded-Proto $scheme;
      proxy_set_header        X-Forwarded-Host $host;
      proxy_set_header        X-Forwarded-Server $host;
    '';
    recommendedOptimisation = lib.mkDefault true;
    recommendedProxySettings = lib.mkForce false; # unrecommend.
    recommendedTlsSettings = lib.mkDefault true;
  };

  documentation.nixos.enable = false;

  services.openssh = {
    enable = true;
    passwordAuthentication = false;
    ports = [ 17788 ];
  };

  services.nginx.package = pkgs.nginxStable.override {
    modules = with pkgs.nginxModules; [ brotli ];
  };

  users.mutableUsers = false;

  nix.nixPath = options.nix.nixPath.default ++ [ "nixpkgs=/etc/nix/nixpkgs" "nixpkgs-overlays=/etc/nix/overlays.nix" ];
  environment.etc."nix/nixpkgs".source = pkgs.path;
  environment.etc."nix/overlays.nix".source = ./overlay/default.nix;
}
