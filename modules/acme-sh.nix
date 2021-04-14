# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ config, lib, pkgs, ... }:

let
  cfg = config.services.acme-sh;
  dnstype = lib.types.enum [ "dns_aws" "dns_dnsimple" ];
submod = with lib;{
  domains = mkOption {
    type = types.coercedTo
      (types.listOf types.str)
      (f: lib.genAttrs f (x: cfg.dns)) (types.attrsOf dnstype);
    default = { "${cfg.mainDomain}" = cfg.dns; };
  };
  mainDomain = mkOption {
    type = types.str;
    description = "domain to use as primary domain for the cert";
  };
  postRun = mkOption {
    type = types.str;
    default = "true";
  };
  keyFile = mkOption {
    type = types.str;
    default = "/dev/null";
  };
  user = mkOption {
    type = types.str;
    default = "root";
    description = "User running the ACME client.";
  };
  
  group = mkOption {
    type = types.str;
    default = "root";
    description = "Group running the ACME client.";
  };

  dns = mkOption {
    type = dnstype;
  };
  renewInterval = mkOption {
    type = types.str;
    default = "weekly";
    description = ''
      Systemd calendar expression when to check for renewal. See
      <citerefentry><refentrytitle>systemd.time</refentrytitle>
      <manvolnum>7</manvolnum></citerefentry>.
    '';
  };
  production = mkOption {
    type = types.bool;
    default = true;
  };
  statePath = mkOption {
    readOnly = true;
    type = types.str;
  };
  keyPath = mkOption {
    readOnly = true;
    type = types.str;
  };
  certPath = mkOption {
    readOnly = true;
    type = types.str;
  };
  consulLock = mkOption {
    type = types.nullOr types.str;
    default = null;
    example = "vault";
  };
};
in
{
  options.services.acme-sh = with lib; {
    stateDir = lib.mkOption {
      type = types.str;
      default = "/var/lib/acme.sh";
    };
    certs = lib.mkOption {
      type = types.attrsOf (types.submodule ({config, name, ...}: (with config; {
        options = submod;
        config.statePath = "${cfg.stateDir}/${name}";
        config.keyPath = "${statePath}/${mainDomain}/${mainDomain}.key";
        config.certPath = "${statePath}/${mainDomain}/fullchain.cer";
      })));
      default = {};
    };
  };
  config = {
    systemd.services = lib.mapAttrs' (name: value: lib.nameValuePair "acme-sh-${name}" (with value; {
      description = "Renew ACME Certificate for ${name}";
      after =
        [ "network.target" "network-online.target" ]
        # wait for consul if we use it for locking
        ++ optional (consulLock != null) [ "consul.service" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        PermissionsStartOnly = true;
        User = user;
        Group = group;
        PrivateTmp = true;
        EnvironmentFile = keyFile;
        SuccessExitStatus = "0 2";
      };
      path = with pkgs; [ acme-sh systemd util-linuxMinimal procps ];
      preStart = ''
        mkdir -p ${cfg.stateDir}
        chown 'root:root' ${cfg.stateDir}
        chmod 755 ${cfg.stateDir}
        mkdir -p "${statePath}"
        chown -R '${user}:${group}' "${statePath}"
        chmod 750 "${statePath}"
        rm -f "${statePath}/renewed"
      '';
      environment.LE_WORKING_DIR = statePath;
      environment.SHELL = "${pkgs.bash}/bin/bash";
      script = let
        mapDomain = name: dns: ''-d "${name}" --dns ${dns}'';
        primary = mapDomain mainDomain domains."${mainDomain}";
        domainsStr = lib.concatStringsSep " " ([primary] ++ (lib.remove primary (lib.mapAttrsToList mapDomain domains)));
        cmd = ''acme.sh --issue ${lib.optionalString (!production) "--test"} ${domainsStr} --reloadcmd "touch ${statePath}/renewed" --syslog 6 > /dev/null'';
      in
        if consulLock == null then ''
        ${cmd}
        rm -f "$LE_WORKING_DIR/account.conf"
      '' else ''
        # consul lock does not expose the exit code, because of platform compatiblity or something
        # write it to the 'ecode' file, or exit 1 if it fails altogether
        if ${config.services.consul.package}/bin/consul lock -verbose "${consulLock}" '${cmd}; echo $? > ${statePath}/ecode'; then
          rm -f "$LE_WORKING_DIR/account.conf"
          exit $(cat ${statePath}/ecode)
        else
          rm -f "$LE_WORKING_DIR/account.conf"
          exit 1
        fi
      '';
      postStart = ''
        if [ -e "${statePath}/renewed" ]; then
          ${postRun}
          rm -f "${statePath}/renewed"
        fi
      '';
    })) cfg.certs;
    systemd.timers = lib.mapAttrs' (name: value: lib.nameValuePair "acme-sh-${name}" (with value; {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = renewInterval;
        Unit = "acme-sh-${name}.service";
        Persistent = "yes";
        AccuracySec = "5m";
        RandomizedDelaySec = "1h";
      };
    })) cfg.certs;
  };

}
