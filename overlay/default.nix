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
  nixUnstable = inputs.nix-unstable.defaultPackage.${final.system};

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

    # Validate a terraform directory.

    # FIXME remote modules don't work since they aren't supported by nixpkgs
    # directly and terraform can't fetch them inside the sandbox
    validateTerraform = { src, terraform ? final.terraform }: final.runCommand "terraform-check"
    { inherit src; buildInputs = [ terraform ]; } ''
      cp -r $src ./terraform
      terraform init -backend=false terraform
      terraform validate terraform
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
