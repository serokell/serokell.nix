# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

let pkgs = import (import ../../nix/sources.nix).nixpkgs { };
in with import ../../.;
with lib.src; {
  no-hash-mismatch = (toString (cleanGit "test" ./test-foo))
    == (toString (cleanGit "test" ./test-bar));
  cleans-git = let
    commit = pkgs.lib.commitIdFromGitRepo ../../.git;
    githubSrc = builtins.fetchGit {
      url = "https://github.com/serokell/serokell.nix";
      rev = commit;
    };
  in (toString (cleanGit "serokell.nix" githubSrc))
  == (toString (cleanGit "serokell.nix" ../../.));
}
