{ nixpkgs
, system ? "x86_64-linux"
, pkgs ? nixpkgs.legacyPackages.${system}, ... }:
let
  mkVM = moduleConfig: serviceConfig: nixpkgs.lib.nixosSystem {
    inherit system pkgs;
    modules = [ ({ ... }: {

      imports = [ moduleConfig.module ];

      services.${moduleConfig.nixOsServiceName} = {
        enable = true;
      } // serviceConfig;

    }) ];
  };

in {
  mkActivateScript = activateScriptName:
      { module, nixOsServiceName, primaryService, auxiliaryServices}@moduleConfig:
      { backupAction ? "", checkAction ? null, restoreAction ? ""}:
      serviceConfig:
    let
      vm = mkVM moduleConfig serviceConfig;
      allServices = [primaryService] ++ auxiliaryServices;
    in
    pkgs.writeShellScriptBin activateScriptName ''
      set -euo pipefail
      export XDG_RUNTIME_DIR="/run/user/$UID"
      mkdir -v -p "$HOME/.config/systemd/user"
      ${pkgs.lib.optionalString (backupAction != "")
        ''
          # Deploy may change DB schema via migration and we should be able
          # to restore its state to a point before an update to successfully rollback
          # failed deployment
          echo Backing up the existing state
          ${backupAction}
        ''
      }

      ${pkgs.lib.concatStringsSep "\n" (builtins.map (service:
        let
          serviceUnit = vm.config.systemd.units.${service};
        in
          ''
            rm -v -f -- "$HOME/.config/systemd/user/${service}"
            ln -v -s ${serviceUnit.unit}/${service} "$HOME/.config/systemd/user/${service}"
          ''
          +
          (pkgs.lib.concatStringsSep "\n" (builtins.map (wantedByTarget:
              ''
                rm -v -f -- "$HOME/.config/systemd/user/${wantedByTarget}.wants/${service}"
                mkdir -v -p "$HOME/.config/systemd/user/${wantedByTarget}.wants"
                ln -v -s "$HOME/.config/systemd/user/${service}" "$HOME/.config/systemd/user/${wantedByTarget}.wants"
              ''
          ) serviceUnit.wantedBy))
        ) allServices)}
      systemctl --user daemon-reload

      ${pkgs.lib.optionalString (restoreAction != "")
        ''
        rollback() {
          exit_code="$?"
          if [[ $exit_code -ne 0 ]]; then
            echo Activation failed, restoring the previous working state
            ${restoreAction}
          fi
          exit "$exit_code"
        }
        trap rollback EXIT
        ''
      }

      ${pkgs.lib.concatStringsSep "\n" (builtins.map (service:
        pkgs.lib.optionalString (builtins.elem "default.target" vm.config.systemd.units.${service}.wantedBy)
        ''
          echo Restarting ${service}
          systemctl --user restart ${service}
        ''
      ) (auxiliaryServices ++ [primaryService]))}

      ${pkgs.lib.optionalString (checkAction != null)
        ''
          retry_count=0
          while [[ "$retry_count" -lt 10 ]]; do
            echo "Checking if the server is up, round $((retry_count+1))"
            set +e
            ${checkAction vm.config.services.${moduleConfig.nixOsServiceName}}
            set -e
            retry_count=$((retry_count+1))
            sleep 5
          done
          # If we didn't manage to get a positive check, fail and cause a rollback
          exit 1
        ''
      }
    '';
}
