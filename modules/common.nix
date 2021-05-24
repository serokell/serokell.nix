# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ lib, pkgs, config, options, inputs, ... }:

{
  imports = [
    ./services/nginx.nix
    ./ssh-hostkeys.nix
    ./nix-gc.nix
  ];

  networking.firewall = {
    allowPing = false;
    logRefusedConnections = false;
  };

  # Default to /tmp on disk, move it to tmpfs if server big enough
  boot.cleanTmpDir = true;

  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" ];
    disabledCollectors = [ "timex" ];
  };

  # veth* are created by docker and don't require DHCP. Disabling it also
  # avoids issues with EC2 instances, because otherwise dhcpcd creates 169.254.0.0/16
  # route, which breaks access to AWS metadata and AWS NTP server.
  # nixpkgs issue: https://github.com/NixOS/nixpkgs/issues/109387
  networking.dhcpcd.denyInterfaces = [ "veth*" ];

  services.mysql.package = lib.mkOptionDefault pkgs.mariadb;
  services.postgresql.package = lib.mkOptionDefault pkgs.postgresql_12;

  nix.autoOptimiseStore = true;

  # Use Wasabi cache
  nix.binaryCaches = ["s3://serokell-private-cache?endpoint=s3.eu-central-1.wasabisys.com&profile=wasabi-cache-read"];
  nix.binaryCachePublicKeys = ["serokell-1:aIojg2Vxgv7MkzPJoftOO/I8HKX622sT+c0fjnZBLj0="];

  nix.extraOptions = ''
    # Allow CI to work when wasabi dies
    fallback = true

    # https://github.com/NixOS/nix/issues/1964
    tarball-ttl = 0

    # Enable flakes and nix-command by default if available
    # Note: causes harmless warning on stable nix about
    #   experimental-features being an unrecognized option
    experimental-features = nix-command flakes
  '';

  programs.mosh.enable = true;

  security.sudo.wheelNeedsPassword = false;

  services.nginx = {
    appendHttpConfig = ''
      if_modified_since off;
    '';
    recommendedOptimisation = lib.mkDefault true;
    recommendedProxySettings = lib.mkDefault true;
    recommendedTlsSettings = lib.mkDefault true;
  };

  security.acme = {
    email = "operations@serokell.io";
    acceptTerms = true;
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

  nixpkgs.overlays = [ (import ./../overlay inputs) ];
  nix.nixPath = [ "nixpkgs=/etc/nix/nixpkgs" ];
  environment.etc."nix/nixpkgs".source = pkgs.path;

  environment.systemPackages = with pkgs; [
    htop
    vim
    rsync
  ];

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "20.03"; # Did you read the comment?
}
