# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

inputs:

final: prev:
let
  inherit (final) lib;
in
{
  # Uses sources.mix-to-nix and sources.gitignore
  nixUnstable = inputs.nix.defaultPackage.${final.system};

  benchwrapper = prev.writeShellScriptBin "benchwrapper" ''
    set -euo pipefail

    # number of cores to run the wrapped program on
    test_cpus="$1"
    shift

    sctl=${prev.systemd}/bin/systemctl
    srun=${prev.systemd}/bin/systemd-run

    #############

    ncpus=$(( $(${prev.util-linux}/bin/lscpu -e | wc -l) - 1 ))

    if [[ -z "$test_cpus" || "$test_cpus" -le 0 || "$test_cpus" -gt "$(( $ncpus / 2 ))" ]]; then
      echo "make sure to double-check `ncpus`"
      exit 1
    fi

    fullrange="0-$(( $ncpus - 1 ))"
    sysrange="0-$(( $ncpus - $test_cpus - 1 ))"
    shieldrange="$(( $ncpus - $test_cpus ))-$(( $ncpus - 1 ))"

    cleanup() {
      # restore full core utilization for all services
      $sctl set-property --runtime system.slice AllowedCPUs="$fullrange"
      $sctl set-property --runtime user.slice AllowedCPUs="$fullrange"
    }

    # make sure to allow scheduling on all cores again in case of error
    trap cleanup EXIT

    # limit user and system services to certain cores
    $sctl set-property --runtime system.slice AllowedCPUs="$sysrange"
    $sctl set-property --runtime user.slice AllowedCPUs="$sysrange"

    # run all arguments as a command using systemd-run inheriting path and limited to $shieldrange cpus
    $srun --nice=-20 --slice shield -EPATH=$PATH --property=AllowedCPUs="$shieldrange" -t -- "$@"

    cleanup
  '';

  build = {
    /*
    * Run a series of commands only for their exit status.
    */
    runCheck = script: final.runCommand "check" {} ''
      {
        ${script}
      } && touch "$out"
    '';

    /*
    * Check the given target path for files with trailing whitespace.
    */
    checkTrailingWhitespace = src: final.build.runCheck ''
      files=$(grep --recursive --exclude-dir LICENSES --exclude '*.patch' --exclude-dir .git --files-with-matches --binary-files=without-match '[[:blank:]]$' "${src}" || true)
      if [[ ! -z $files ]]; then
        echo 'Files with trailing whitespace:'
        for f in "''${files[@]}"; do
          echo "  * $f" | sed -re "s|${src}/||"
        done
        exit 1
      fi
    '';

    reuseLint = src: final.build.runCheck ''
      ${final.reuse}/bin/reuse --root "${src}" lint
    '';

    terraformWithModules = { terraform ? final.terraform, terraformDirs ? { "terraform" = []; } }: let
      addModulesForDirs = lib.mapAttrsToList (dir: modules: let
        addModules = map ({ name, path }: ''
          rm -rf "$p/${name}"
          ln -s ${path} "$p/${name}"
        '') modules;
        in ''
          p="$PWD/${dir}/.terraform_nix/modules"
          mkdir -p "$p"
          ${lib.concatStringsSep "\n" addModules}
        '') terraformDirs;
    in final.writeScriptBin "terraform" ''
      while [[ "$PWD" != '/' ]] && [ ! -f 'flake.nix' ]; do
        cd ..
      done

      if [ "$PWD" = '/' ]; then
        exit 1
      fi

      ${lib.concatStringsSep "\n" addModulesForDirs}

      ${terraform}/bin/terraform "$@"
    '';

    # Validate terraform directory
    validateTerraform = { src, path ? "terraform", terraform ? final.terraform }: final.runCommand "terraform-check" { } ''
      cp -a --no-preserve=mode ${src}/. .
      ${terraform}/bin/terraform -chdir=${path} init -backend=false
      ${terraform}/bin/terraform -chdir=${path} validate
      touch $out
    '';

    haskell = {
      hlint = src: final.runCommand "hlint.html" {} ''
        ${final.hlint}/bin/hlint "${src}" --no-exit-code --report=$out -j
      '';

      haddock = name: docs:
        let
          globs = map (doc: "${doc}/share/doc/*") docs;
        in final.runCommand "${name}-haddock.tar.gz" {} ''
          for drv in ${final.concatStringsSep " " globs}; do
            ln -s "$drv"/html $(basename "$drv")
          done

          tar czfh "$out" *
        '';
    };
  };
}
