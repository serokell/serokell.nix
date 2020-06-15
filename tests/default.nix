{ self ? import ../., lib ? self.inputs.nixpkgs.lib }:
let inherit (self.lib.src) cleanGit; in {
  no-hash-mismatch = (toString (cleanGit "test" ./test-foo))
    == (toString (cleanGit "test" ./test-bar));
  cleans-git = let
    commit = lib.commitIdFromGitRepo ../.git;
    githubSrc = builtins.fetchGit {
      url = "https://github.com/serokell/serokell.nix";
      rev = commit;
    };
  in (toString (cleanGit "serokell.nix" githubSrc))
  == (toString (cleanGit "serokell.nix" ../.));
}
