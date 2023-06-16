{ config, lib, ... }:
{
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
    wireguard-peer-persistent-keepalive = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      description = "Optional PersistentKeepalive value for server peer in client config";
      default = null;
    };
  };
  polisPeer = {
    allowedIPs = config.wireguard-allowed-ips;
    endpoint = "polis.sagittarius.serokell.team:51820";
    publicKey = "gOS8bfFuFJmEpaZa19i2Q62gKAaTyL+XWCJvmxekqy8=";
    persistentKeepalive = config.wireguard-peer-persistent-keepalive;
  };
}
