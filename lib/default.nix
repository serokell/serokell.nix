# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ pkgs, gitignore }:

let
  inherit (pkgs.lib) cleanSourceFilter removePrefix hasPrefix hasSuffix;
  inherit (gitignore) gitignoreFilter;
in

{
  /* Ignore files ignored by .gitignore and some other extra stuff.
   * Also set a constant path name to avoid different hashes on different
   * systems.
   */
   # TODO: Maybe replace with cleanGit from haskell.nix
  cleanSource = name: path:
    let
      ignoreFilter = path: type:
        let
          relPath = removePrefix (toString ./. + "/") (toString path);
          baseName = baseNameOf relPath;
        in
          !(
            baseName == ".gitignore" ||
            hasPrefix "resources" relPath ||
            hasSuffix ".md" baseName
          );
    in builtins.path {
      inherit name path;
      filter = name: type:
        ignoreFilter name type &&
        gitignoreFilter path name type &&
        cleanSourceFilter name type;
    };
}
