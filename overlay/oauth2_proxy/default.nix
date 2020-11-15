# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ lib, buildGoPackage, fetchFromGitHub }:

buildGoPackage rec {
  name = "oauth2_proxy-${version}";
  version = "20200506-${lib.strings.substring 0 7 rev}";
  rev = "d1a697508ee73081a82e558424e15f07953bc589";

  goPackagePath = "github.com/pusher/oauth2_proxy";

  src = fetchFromGitHub {
    repo = "oauth2_proxy";
    owner = "serokell";
    inherit rev;
    sha256 = "02vrrv9iyj0ky229chsjwl9x1xbvw53k991hpn46zxgc90k5qj4s";
  };

  goDeps = ./deps.nix;

  # we use a custom patch which breaks the tests
  doCheck = false;
}
