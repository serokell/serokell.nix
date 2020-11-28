# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{
  description = "Serokell Nix infrastructure library";

  inputs = {
    nixpkgs.url = "github:serokell/nixpkgs";
    nix-unstable.url = "github:nixos/nix";
    haskell-nix.url = "github:input-output-hk/haskell.nix/bd45da822d2dccdbb3f65d0b52dd2a91fd65ca4e";

    gitignore-nix = {
      url = "github:hercules-ci/gitignore.nix";
      flake = false;
    };

    flake-utils.url = "github:numtide/flake-utils";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, gitignore-nix, flake-utils, ... }@inputs: ({
    overlay = import ./overlay inputs;

    lib = import ./lib {
      inherit (nixpkgs) lib;
      gitignore-nix = import gitignore-nix { inherit (nixpkgs) lib; };
    };

    nixosModules = {
      common = import ./modules/common.nix;

      acme-sh = import ./modules/acme-sh.nix;
      vault-secrets = import ./modules/vault-secrets.nix;
      serokell-users = import ./modules/serokell-users.nix;
      hackage-search = import ./modules/services/hackage-search.nix;
      mtg = import ./modules/services/mtg.nix;
      nginx = import ./modules/services/nginx.nix;
      oauth2_proxy = import ./modules/services/oauth2_proxy.nix;
      oauth2_proxy_nginx = import ./modules/services/oauth2_proxy_nginx.nix;
      upload-daemon = import ./modules/services/upload-daemon.nix;
      hetzner-cloud = import ./modules/virtualization/hetzner-cloud.nix;
    };
  } // flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ self.overlay ];
      };
    in with pkgs; {
      devShell = mkShell {
        buildInputs = [
          nixUnstable
        ];
      };
      packages = {
        inherit (pkgs) oauth2_proxy youtrack mtg nixUnstable;
      };
  }));
}
