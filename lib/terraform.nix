{ nixpkgs, lib, ...}:
let
  inherit (lib) nameValuePair mapAttrs' genAttrs;
  inherit (builtins) toString toJSON;
  addTFPrefix = mapAttrs' (n: nameValuePair "tf-${n}");
  defaultSubDir = "$(mktemp -d)";
in
{ system ? "x86_64-linux"
, pkgs ? nixpkgs.legacyPackages.${system}
, terraform ? pkgs.terraform
, tfConfigAst ? null
, subdir ? defaultSubDir
, backend ? true
}:
rec {
  tfConfig = pkgs.runCommand "config.tf.json" {} ''
    echo '${toJSON tfConfigAst.config}' | ${pkgs.jq}/bin/jq . > $out
  '';

  mkApp = let
    defaultSubDir = subdir;
    defaultBackend = backend;
    defaultTFConfig = tfConfig;

    vaultLogin = if tfConfigAst.config ? "provider"."vault"."address" then ''
    export VAULT_ADDR='${tfConfigAst.config."provider"."vault"."address"}'
    ${pkgs.vault}/bin/vault token lookup >/dev/null 2>&1 || ${pkgs.vault}/bin/vault login -method=oidc
    '' else "";

  in { command, tfConfig ? defaultTFConfig, subdir ? defaultSubDir, backend ? defaultBackend }: {
    type = "app";
    program = toString (pkgs.writers.writeBash command ''
      pushd ${toString subdir} >/dev/null
      ${vaultLogin}
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
