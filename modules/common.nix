# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ lib, pkgs, config, options, inputs, ... }:

{
  imports = [
    ./services/nginx.nix
    ./ssh-hostkeys.nix
  ];

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

  # Use Wasabi cache
  nix.binaryCaches = ["s3://serokell-private-cache?endpoint=s3.eu-central-1.wasabisys.com&profile=wasabi-cache-read"];
  nix.binaryCachePublicKeys = ["serokell-1:aIojg2Vxgv7MkzPJoftOO/I8HKX622sT+c0fjnZBLj0="];

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
