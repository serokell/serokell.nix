# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ config, lib, pkgs, ... }:

with lib;

{
  options.secrets = mkOption {
    default = {};
    example.gitlab-runner = {
      transform = "sed -f /etc/gitlab-runner/secrets.sed";
      services = [ "gitlab-runner" ];
      source = writeText "gitlab-runner.toml" ''
        [[runners]]
        executor = "shell"
        name = "example-runner"
        token = "INSERT_TOKEN"
        url = "https://gitlab.com"
      '';
    };

    description = ''
      The secrets module provides an easy way to inject secrets into
      configuration files. A secret starts with a <literal>source</literal>
      file, which is piped through a <literal>transform</literal> shell command
      and then written to a file <literal>name</literal> in
      <literal>destDir</literal>.

      A common usage pattern is to write a configuration file to the nix store
      with dummy names instead of the secrets. This file is then used as source,
      and a sed script stored outside the nix store is used in the transform
      command to replace those dummy names with the actual secrets. It also
      possible to use only a source with secrets stored outside the nix store,
      or only a writeShellScript result as transform which generates secrets
      without reading from stdin.
    '';

    type = types.loaOf (types.submodule (
      { name, config, ... }: {
        options = rec {
          destDir = mkOption {
            default = "/run/secrets";
            type = types.path;
            description = ''
              When specified, this allows changing the destDir directory of the secret
              file from its default value of <filename>${destDir.default}</filename>.

              This directory will be created, its permissions changed to
              <literal>0555</literal> and ownership to <literal>root:root</literal>.
            '';
          };

          path = mkOption {
            type = types.path;
            default = "${config.destDir}/${name}";
            defaultText = "destDir/name";
            description = ''
              Path to the destination of the file, a shortcut to
              <literal>destDir</literal> + / + <literal>name</literal>

              Example: For secret named <literal>foo</literal>,
              this option would have the value <literal>${destDir.default}/foo</literal>.
            '';
          };

          user = mkOption {
            default = "root";
            type = types.str;
            description = ''
              The user that will be the owner of the secret.
            '';
          };

          group = mkOption {
            default = "root";
            type = types.str;
            description = ''
              The group that will be set for the secret.
            '';
          };

          permissions = mkOption {
            default = "0440";
            type = types.str;
            description = ''
              The default permissions to set for the secret, needs to be in the
              format accepted by <citerefentry><refentrytitle>chmod</refentrytitle>
              <manvolnum>1</manvolnum></citerefentry>.
            '';
          };

          services = mkOption {
            default = [];
            type = types.listOf types.str;
            description = ''
              Systemd services that depend on this secret.
            '';
          };

          source = mkOption {
            default = "/dev/null";
            type = types.path;
            description = ''
              The source file for the secret that is piped through transform.
            '';
          };

          transform = mkOption {
            type = types.str;
            default = "cat";
            example = "sed -f /path/to/secrets.sed";
            description = ''
              Shell command to pipe the source through. This command is run as
              root.
            '';
          };

          __toString = mkOption {
            default = self: self.path;
            readOnly = true;
          };
        };
      }
    ));
  };

  config = {
    systemd.services = lib.mkMerge ([(flip mapAttrs' config.secrets (
      name: { destDir, path, permissions, user, group, source, transform, ... }:
      nameValuePair "${name}-secret" rec {
        serviceConfig.Type = "oneshot";
        script = ''
          mkdir -p ${destDir}
          chmod 0555 ${destDir}
          chown root:root ${destDir}
          touch ${path}
          chmod ${permissions} ${path}
          chown ${user}:${group} ${path}
          ${transform} > ${path} < ${source}
        '';
      }
    ))] ++ (flip lib.mapAttrsToList config.secrets (
      name: { services, ... }:
      lib.genAttrs services (services: rec {
        requires = [ "${name}-secret.service" ];
        after = requires;
        restartTriggers = [
          config.systemd.services."${name}-secret".serviceConfig.ExecStart
        ];
      }))
    ));
  };
}
