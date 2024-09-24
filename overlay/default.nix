# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0
{ inputs }:
final: prev:
let
  inherit (final) lib;
  /*
  * Run a series of commands only for their exit status.
  */
  runCheck = name: script: final.runCommand name {} ''
    {
      ${script}
    } && touch "$out"
  '';
in
{
  benchwrapper = prev.writers.writePython3Bin "benchwrapper" {} (builtins.readFile ./benchwrapper.py);

  build = {
    inherit runCheck;

    /*
    * Check the given target path for files with trailing whitespace.
    */
    checkTrailingWhitespace = src: final.build.runCheck "check-trailing-whitespace" ''
      files=$(grep --recursive --exclude-dir LICENSES --exclude '*.patch' --exclude-dir .git --files-with-matches --binary-files=without-match '[[:blank:]]$' "${src}" || true)
      if [[ ! -z $files ]]; then
        echo 'Files with trailing whitespace:'
        for f in "''${files[@]}"; do
          echo "  * $f" | sed -re "s|${src}/||"
        done
        exit 1
      fi
    '';

    reuseLint = src: final.build.runCheck "reuse-lint" ''
      ${final.reuse}/bin/reuse --root "${src}" lint
    '';

    shellcheck = src: final.build.runCheck "shellcheck" ''
      find . -name '*.sh' -exec "${final.shellcheck}/bin/shellcheck" {} +
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
      hlint = src: runCheck "hlint" ''
        cd ${src}
        ${final.haskellPackages.hlint}/bin/hlint .
      '';
      stylish-haskell = src: runCheck "stylish-haskell" ''
          files=()
          cd ${src}
          while IFS=  read -r -d $'\0'; do
            files+=("$REPLY")
          done < <(find . -name '.stack-work' -prune -o -name '.dist-newstyle' -prune -o -name '*.hs' -print0)
          exit_code="0"
          for file in "''${files[@]}"; do
            set +e
            diff="$("${final.haskellPackages.stylish-haskell}/bin/stylish-haskell" "$file" | diff -u "$file" -)"
            if [ "$diff" != "" ]; then
                echo "$file"
                echo "$diff"
                exit_code="1"
            fi
            set -e
          done
          if [[ "$exit_code" != "0" ]]; then
            exit "$exit_code"
          fi
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

      hpack = src: runCheck "hpack" ''
        cp -a --no-preserve=mode ${src}/. ./new
        cd ./new
        ${final.hpack}/bin/hpack
        diff -q -r ${src} .
      '';

      cabal-check = src: runCheck "cabal check" ''
        cd ${src}
        ${final.cabal-install}/bin/cabal check
      '';

      # in order for this check to work, you must set writeHieFiles = true
      # in the module configuration of your hs-pkgs
      weeder = { weederToml, hs-pkgs }: let
        haskellPkgs = inputs.haskell-nix.legacyPackages.x86_64-linux;

        # get local package names
        pkg-names = lib.attrNames (lib.filterAttrs (_: v: (builtins.isAttrs v) && v ? isLocal && v.isLocal) hs-pkgs);

        # get all hie files
        allHieFiles = final.linkFarmFromDrvs "all-hie-files" (lib.concatMap (name: let
          hs-pkg = hs-pkgs.${name}.components;
        in (map (component: component.hie) (
          lib.optional (hs-pkg ? library) hs-pkg.library
          ++ lib.attrValues hs-pkg.exes
          ++ lib.attrValues hs-pkg.tests))) pkg-names);

        # we need weeder to be built using the exact same ghc that is used to generate hie files
        weeder = (haskellPkgs.haskell-nix.project {
          compiler-nix-name = "ghc${builtins.replaceStrings ["."] [""] hs-pkgs.ghc.identifier.version}";
          cabalProjectLocal = builtins.readFile "${inputs.weeder-src}/cabal.project.haskell-nix";
          src = haskellPkgs.haskell-nix.haskellLib.cleanGit {
            name = "weeder";
            src = inputs.weeder-src;
          };
          modules = [ { reinstallableLibGhc = false; } ];
        }).weeder.components.exes.weeder;

      in runCheck "weeder check" ''
        cd ${allHieFiles}
        ${weeder}/bin/weeder --config ${weederToml}
      '';
    };
  };

  github = import ./github.nix { inherit (final) gh git writeShellApplication; };
}
