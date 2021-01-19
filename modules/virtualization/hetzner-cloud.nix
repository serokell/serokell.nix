{ config, lib, pkgs, modulesPath, ... }:

let
  cfg = config.hetzner;

in {
  imports = [ "${modulesPath}/profiles/qemu-guest.nix" ];

  options = {
    hetzner = {
      ipv6Address = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        description = "IPv6 address for the instance";
      };
    };
  };

  config = {
    boot.loader.grub.device = "/dev/sda";
    fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };

    networking = lib.mkIf (cfg.ipv6Address != null) {
      # make sure interface name is always eth0
      usePredictableInterfaceNames = false;

      # set ipv6 address and gateway statically, because hetzner cloud
      # does not have dhcpv6
      interfaces.eth0.ipv6.addresses = [{
        address = cfg.ipv6Address;
        prefixLength = 64;
      }];
      defaultGateway6 = {
        address = "fe80::1";
        interface = "eth0";
      };
    };
  };
}
