# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ stdenv, fetchFromGitHub, openssl, zlib }:

stdenv.mkDerivation {
  name = "mtproxy";
  src = fetchFromGitHub {
    owner = "TelegramMessenger";
    repo = "MTProxy";
    rev = "2c942119c4ee340c80922ba11d14fb3b10d5e654";
    sha256 = "10r4igjj7jz5a64a4lbwwramij64nq5gsb91y5bzbpi28rlwrgmz";
  };
  buildInputs = [ openssl zlib ];
  hardeningDisable = [ "format" ];
  installPhase = ''
        mkdir -p $out/bin
        cp objs/bin/mtproto-proxy $out/bin/mtproto-proxy
  '';
}
