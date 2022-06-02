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
      files=$(grep --recursive --exclude-dir LICENSES --exclude '*.patch' --files-with-matches --binary-files=without-match '[[:blank:]]$' "${src}" || true)
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
          p="$PWD/terraform/${dir}/.terraform_nix/modules"
          mkdir -p "$p"
          ${lib.concatStringsSep "\n" addModules}
        '') terraformDirs;
    in final.writeScriptBin "terraform" ''
      while [[ "$PWD" != '/' ]]; do
        if [ -f 'flake.nix' ]; then
          break
        fi
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
