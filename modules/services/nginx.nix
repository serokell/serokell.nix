# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ config, lib, ... }:

with lib;

let
  cfg = config.services.nginx;
in

{
  options = {
    services.nginx.openFirewall = mkOption {
      default = false;
      type = types.bool;
    };
  };

  config = mkIf cfg.openFirewall {
    # TODO: this obviously doesn't work if custom ports are used, but that
    # can be added later to the module, API won't have to be changed.
    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
