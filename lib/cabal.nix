{ lib, nixpkgs, get-tested }: let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
in {
  # This function extracts GHC versions in the format used by haskell.nix
  # from a "tested-with" stanza in the cabal file
  getTestedWithVersions = cabalFile: let
    ghcVersionsFile = pkgs.runCommand "ghcVersions" {} ''
      ${get-tested}/bin/get-tested ${cabalFile} | ${pkgs.gnused}/bin/sed 's/\.//g' >> $out
    '';
    ghcVersions = builtins.fromJSON (lib.readFile ghcVersionsFile);
  in map (v: "ghc${v}") ghcVersions;
}
