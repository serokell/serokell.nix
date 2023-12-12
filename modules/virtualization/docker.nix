# SPDX-FileCopyrightText: 2023 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.virtualisation.docker;
  inherit (builtins) attrNames;

  mkUncreateMaybe = networks: volumes: ''
    set -euo pipefail
    nexisting=$(${pkgs.coreutils}/bin/mktemp)
    nwanted=$(${pkgs.coreutils}/bin/mktemp)
    vexisting=$(${pkgs.coreutils}/bin/mktemp)
    vwanted=$(${pkgs.coreutils}/bin/mktemp)
    cleanup() {
      rm -f "$nexisting" "$nwanted" "$vexisting" "$vwanted"
    }
    trap cleanup EXIT
    ${pkgs.docker}/bin/docker network ls --format '{{.Name}}' > "$nexisting"
    echo -e "bridge\nhost\nnone\n${concatStringsSep "\n" networks}" > "$nwanted"
    ${pkgs.docker}/bin/docker volume ls --format '{{.Name}}' > "$vexisting"
    echo -e "${concatStringsSep "\n" volumes}" > "$vwanted"
    nsuperfluous="$(${pkgs.gnugrep}/bin/grep -vxF -f $nwanted $nexisting || true)"
    vsuperfluous="$(${pkgs.gnugrep}/bin/grep -vxF -f $vwanted $vexisting || true)"
    while read -r net; do
      if [[ ! -z "$net" ]]; then
        if [[ -f /etc/docker/network-opts/$net ]]; then
          echo -n "Removed superfluous Docker network: "
          ${pkgs.docker}/bin/docker network rm "$net" || true
          rm -f /etc/docker/network-opts/$net
        else
          echo "Skipped deleting Docker network $net as it was manually created (/etc/docker/network-opts/$net is missing)."
        fi
      fi
    done <<< "$nsuperfluous"
    while read -r vol; do
      if [[ ! -z "$vol" ]]; then
        if [[ -f /etc/docker/volumes/$vol ]]; then
          echo -n "Removed superfluous Docker volume: "
          ${pkgs.docker}/bin/docker volume rm "$vol" || true
          rm -f /etc/docker/volumes/$vol
        else
          echo "Skipped deleting Docker volume $vol as it was manually created (/etc/docker/volumes/$vol is missing)."
        fi
      fi
    done <<< "$vsuperfluous"
  '';

  mkNetworkOpts = opts: concatStringsSep " "
    ([ "--driver=${opts.driver}" ]
    ++ optional (opts ? subnet && opts.subnet != null) "--subnet=${opts.subnet}"
    ++ optional (opts ? ip-range && opts.ip-range != null) "--ip-range=${opts.ip-range}"
    ++ optional (opts ? gateway && opts.gateway != null) "--gateway=${opts.gateway}"
    ++ optional (opts ? ipv6 && opts.ipv6) "--ipv6"
    ++ optional (opts ? internal && opts.internal) "--internal");

  mkNetwork = recreate: name: opts: let
    create = ''
      ln -s ${pkgs.writeText name (mkNetworkOpts opts)} "/etc/docker/network-opts/${name}"
      echo "*** docker network create ${mkNetworkOpts opts} ${name}"
      ${pkgs.docker}/bin/docker network create ${mkNetworkOpts opts} ${name}
    '';
  in ''
    mkdir -p /etc/docker/network-opts/
    if [[ $(${pkgs.docker}/bin/docker network ls --quiet --filter name=^${name}$ | wc -c) -eq 0 ]]; then
      rm -f /etc/docker/network-opts/${name}
      ${create}
    elif [[ "${toString recreate}" ]]; then
      oldOpts="$(cat /etc/docker/network-opts/${name} || true)"
      if [ "$oldOpts" != "${mkNetworkOpts opts}" ]; then
        # If oldOpts is different from new ones, disconnect all containers and recreate the network
        for i in `${pkgs.docker}/bin/docker network inspect -f '{{range .Containers}}{{.Name}} {{end}}' ${name}`; do
          echo "*** disconnect container $i from network ${name}"
          ${pkgs.docker}/bin/docker network disconnect -f ${name} $i
        done
        ${pkgs.docker}/bin/docker network rm ${name}
        rm -f /etc/docker/network-opts/${name}
        ${create}
      fi
    fi
  '';

  mkVolume = name: ''
    mkdir -p /etc/docker/volumes/
    if [[ $(${pkgs.docker}/bin/docker volume ls --quiet --filter name=^${name}$ | wc -c) -eq 0 ]]; then
      echo "*** docker volume create ${name}"
      ${pkgs.docker}/bin/docker volume create ${name}
      touch /etc/docker/volumes/${name}
    fi
  '';
in {
  options.virtualisation.docker = {
    volumes = mkOption {
      default = [];
      type = types.listOf types.str;
      example = [ "volume_1" "volume_2" ];
      description = ''
        A list of named volumes that should be created.
      '';
    };

    networks = mkOption {
      default = {};
      type = types.attrsOf (types.submodule {
        options = {
          driver = mkOption {
            default = "bridge";
            type = types.str;
            example = "overlay";
            description = ''
              Driver to manage the network. One of bridge, or overlay.
            '';
          };

          subnet = mkOption {
            default = null;
            type = types.nullOr types.str;
            example = "172.28.0.0/16";
            description = ''
              Subnet in CIDR format that represents a network segment.
            '';
          };

          ip-range = mkOption {
            default = null;
            type = types.nullOr types.str;
            example = "172.28.5.0/24";
            description = ''
              Allocate container ip from a sub-range.
            '';
          };

          gateway = mkOption {
            default = null;
            type = types.nullOr types.str;
            example = "172.28.5.254";
            description = ''
              IPv4 or IPv6 Gateway for the master subnet.
            '';
          };

          ipv6 = mkOption {
            default = false;
            type = types.bool;
            example = true;
            description = ''
              Enable IPv6 networking.
            '';
          };

          internal = mkOption {
            default = false;
            type = types.bool;
            example = true;
            description = ''
              Restrict external access to the network.
            '';
          };
        };
      });

      example = {
        my-network = {
          driver = "bridge";
          subnet = "172.28.0.0/16";
          ip-range = "172.28.5.0/24";
          gateway = "172.28.5.254";
        };
      };

      description = ''
        A list of named networks to be created.
      '';
    };
    unsafeRecreateNetworks = mkEnableOption ''
      When enabled, docker will disconnect all containers
      connected to the modified network and recreate it.
      Unmodified networks will not be affected.
    '';
  };

  config = {
    systemd.services.docker.postStart =
      mkUncreateMaybe (attrNames cfg.networks) cfg.volumes
      + concatStrings (mapAttrsToList (mkNetwork cfg.unsafeRecreateNetworks) cfg.networks)
      + concatStrings (map mkVolume cfg.volumes);

    virtualisation.docker.daemon.settings.log-level = lib.mkDefault "info";

    warnings =
      optional cfg.unsafeRecreateNetworks
        "The cfg.unsafeRecreateNetworks option is enabled, all containers connected to the modified networks will be disabled." ++
      optional (!cfg.unsafeRecreateNetworks)
        "The cfg.unsafeRecreateNetworks option is disabled, no modification to existing networks will be applied.";
  };
}
