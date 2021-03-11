{ config, lib, pkgs, modulesPath, ... }:

{
  # standard ec2 setup
  imports = [ "${modulesPath}/virtualisation/amazon-image.nix" ];

  # amazon-init service fetches system config from userdata, we don't need it
  virtualisation.amazon-init.enable = false;

  # By default 'network-online.target' is activated as soon as either an ipv4
  # or an ipv6 address has been assigned. But for AWS instances we want to wait
  # for an ipv4 address, because DNS resolving will not work without it
  networking.dhcpcd.wait = lib.mkDefault "ipv4";
}
