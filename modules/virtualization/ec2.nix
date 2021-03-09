{ config, lib, pkgs, modulesPath, ... }:

{
  # standard ec2 setup
  imports = [ "${modulesPath}/virtualisation/amazon-image.nix" ];

  # amazon-init service fetches system config from userdata, we don't need it
  virtualisation.amazon-init.enable = false;
}
