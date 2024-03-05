{ lib }:
{

  hardeningProfiles = import ./profiles.nix;

  hardenServices = import ./harden-services.nix;

  userLevelServices = import ./user-level-services.nix;

  withHardeningProfile = profile: serviceConfig: lib.mkMerge [
    (builtins.mapAttrs (_: lib.mkDefault) profile)
    serviceConfig
  ];
}
