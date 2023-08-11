{ pkgs, config, lib, ... }:
let
  inherit (lib) mkOption mkEnableOption mkIf types;
  cfg = config.services.postgresql-migrate;
in {
  options.services.postgresql-migrate = {
    enable = mkEnableOption "postgresql-migration";
    old-postgresql = mkOption {
      type = types.package;
      description = "Old postgresql package to migrate from";
    };
    new-postgresql = mkOption {
      type = types.package;
      description = "New postgresql package to migrate to";
    };
  };
  config = mkIf cfg.enable {
    systemd.services.postgresql-migrate = {
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "postgres";
        Group = "postgres";
        StateDirectory = "postgresql";
        WorkingDirectory = "${builtins.dirOf config.services.postgresql.dataDir}";
      };
      script = let
         oldDataDir = "${builtins.dirOf config.services.postgresql.dataDir}/${cfg.old-postgresql.psqlSchema}";
         newDataDir = "${config.services.postgresql.dataDir}";
      in ''
        if [[ ! -d ${newDataDir} ]]; then
          install -d -m 0700 -o postgres -g postgres "${newDataDir}"
          ${cfg.new-postgresql}/bin/initdb -D "${newDataDir}"
          ${cfg.new-postgresql}/bin/pg_upgrade --old-datadir "${oldDataDir}" --new-datadir "${newDataDir}" \
            --old-bindir "${cfg.old-postgresql}/bin" --new-bindir "${cfg.new-postgresql}/bin"
        else
          echo "${newDataDir} already exists, not performing migration"
        fi
      '';
    };
    systemd.services.postgresql = {
      after = [ "postgresql-migrate.service" ];
      requires = [ "postgresql-migrate.service" ];
    };
  };
}
