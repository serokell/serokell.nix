{ fetchFromGitHub,  buildGoPackage }:
let
  src = fetchFromGitHub {
    owner = "9seconds";
    repo = "mtg";
    rev = "586ac9dcb96b3b99c39f0a33049ab57f7e8be1fe";
    sha256 = "sha256-BnixJiyVNGZG+ZOse79VsJOFZ14dHhI5pJch3FBcbCw=";
    fetchSubmodules = true;
  };
in buildGoPackage rec {
  name = "mtg";
  inherit src;
  version = "master";
  goPackagePath = "github.com/9seconds/mtg";
  goDeps = ./deps.nix;
}
