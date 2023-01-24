{ nixpkgs, lib, ...}:
let
  inherit (lib) nameValuePair mapAttrs' genAttrs;
  inherit (builtins) toString;
  addTFPrefix = mapAttrs' (n: nameValuePair "tf-${n}");
  defaultSubDir = "$(mktemp -d)";
in
{ system ? "x86_64-linux"
, pkgs ? nixpkgs.legacyPackages.${system}
, terraform ? pkgs.terraform
, tfConfig ? null
, subdir ? defaultSubDir
, backend ? true
}:
rec {
  mkApp = let
    defaultSubDir = subdir;
    defaultBackend = backend;
    defaultTFConfig = tfConfig;
  in { command, tfConfig ? defaultTFConfig, subdir ? defaultSubDir, backend ? defaultBackend }: {
    type = "app";
    program = toString (pkgs.writers.writeBash command ''
      pushd ${toString subdir} >/dev/null
      if [[ -e config.tf.json ]]; then rm -f config.tf.json; fi
      cp ${tfConfig} config.tf.json \
        && ${terraform}/bin/terraform init ${if backend then "-upgrade" else "-backend=false"} \
        && ${terraform}/bin/terraform ${toString command}
      popd >/dev/null
    '');
  };

  mkApps = commands: addTFPrefix (genAttrs commands (command: mkApp { inherit command; }));

  tf-validate = pkgs.runCommand "terraform-validate" {} ''
    cp ${tfConfig} ./config.tf.json
    ${terraform}/bin/terraform init -backend=false \
     && ${terraform}/bin/terraform validate \
     && mkdir -p $out
  '';
}
