{ config, lib, ... }:
let
  applyProfile = builtins.mapAttrs (_: lib.mkDefault);
  profiles = import ./profiles.nix;
in with profiles; {
  systemd.services = {
    postgresql.serviceConfig = lib.mkIf (config.services.postgresql.enable) (applyProfile backend_unix_socket);
  };
}
