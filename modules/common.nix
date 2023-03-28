# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ lib, pkgs, config, options, inputs, ... }:
{
  imports = [
    ./ssh-hostkeys.nix
    ./nix-gc.nix
  ];

  config = {
    environment.etc."default/atop".text = ''
      LOGOPTS=""
      LOGINTERVAL=600
      LOGGENERATIONS=7
    '';

    nix.settings.auto-optimise-store = true;

    # Use Wasabi cache
    nix.settings.substituters = ["s3://serokell-private-cache?endpoint=s3.eu-central-1.wasabisys.com&profile=wasabi-cache-read"];
    nix.settings.trusted-public-keys = ["serokell-1:aIojg2Vxgv7MkzPJoftOO/I8HKX622sT+c0fjnZBLj0="];

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


    nixpkgs.overlays =
      [ (import ./../overlay) ];

    nix.nixPath = [ "nixpkgs=/etc/nix/nixpkgs" ];

    # A hack to get around Nix not recognizing a runtime dependency on nixpkgs
    environment.etc."nix/nixpkgs".source = "${pkgs.path}";

    environment.systemPackages = with pkgs; [
      htop
      vim
      rsync
    ];
  };
}
