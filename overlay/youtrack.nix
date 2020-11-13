# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ stdenv, makeWrapper, jre, gawk }:

let
  rev = builtins.fromJSON (builtins.readFile ./youtrack_rev.json);
in
stdenv.mkDerivation rec {
  version = rev.version;
  name = "youtrack-${version}";

  jar = builtins.fetchurl {
    url = rev.url;
    sha256 = rev.sha256;
  };

  buildInputs = [ makeWrapper ];

  unpackPhase = ":";

  installPhase = ''
    runHook preInstall
    makeWrapper ${jre}/bin/java $out/bin/youtrack \
      --add-flags "\$YOUTRACK_JVM_OPTS -jar $jar" \
      --prefix PATH : "${stdenv.lib.makeBinPath [ gawk ]}" \
      --set JRE_HOME ${jre}
    runHook postInstall
  '';

  meta = with stdenv.lib; {
    description = "Issue tracking and project management tool for developers";
    maintainers = with maintainers; [ yorickvp ];
    # https://www.jetbrains.com/youtrack/buy/license.html
    license = licenses.unfree;
  };
}
