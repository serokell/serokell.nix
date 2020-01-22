# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ pkgs }:

let
  inherit (pkgs.lib) concatStringsSep;
in

final: _prev: {
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
      files=$(grep --recursive --files-with-matches --binary-files=without-match '[[:blank:]]$' "${src}" || true)
      if [[ ! -z $files ]]; then
        echo 'Files with trailing whitespace:'
        for f in "''${files[@]}"; do
          echo "  * $f" | sed -re "s|${src}/||"
        done
        exit 1
      fi
    '';

    haskell = {
      hlint = src: final.runCommand "hlint.html" {} ''
        ${pkgs.hlint}/bin/hlint "${src}" --no-exit-code --report=$out -j
      '';

      haddock = name: docs:
        let
          globs = map (doc: "${doc}/share/doc/*") docs;
        in final.runCommand "${name}-haddock.tar.gz" {} ''
          for drv in ${concatStringsSep " " globs}; do
            ln -s "$drv"/html $(basename "$drv")
          done

          tar czfh "$out" *
        '';
    };
  };
}
