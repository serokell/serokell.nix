# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{
  description = "Serokell Nix infrastructure library";

  nixConfig.flake-registry = "https://github.com/serokell/flake-registry/raw/master/flake-registry.json";

  inputs = {
    gitignore-nix = {
      url = "github:hercules-ci/gitignore.nix";
      flake = false;
    };

    flake-compat = {
      flake = false;
    };
    get-tested-src = {
      url = "github:Sereja313/get-tested/issue-8-emit-ghc-versions";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, gitignore-nix, flake-utils, nix, deploy-rs, haskell-nix, ... }@inputs: let
    get-tested = (haskell-nix.legacyPackages.x86_64-linux.haskell-nix.cabalProject {
      src = haskell-nix.legacyPackages.x86_64-linux.haskell-nix.haskellLib.cleanGit {
        name = "get-tested";
        src = inputs.get-tested-src;
      };
      compiler-nix-name = "ghc944";
    }).get-tested.components.exes.get-tested;

  in ({
    overlay = import ./overlay;

    lib = import ./lib {
      inherit nixpkgs deploy-rs get-tested;
      inherit (nixpkgs) lib;
      gitignore-nix = import gitignore-nix { inherit (nixpkgs) lib; };
    };

    darwinModules = {
      common = import ./modules/common.nix;
      serokell-users = import ./modules/serokell-users-darwin.nix;
      wireguard-monitoring = import ./modules/wireguard-monitoring/darwin.nix;
    };

    nixosModules = {
      common = {...}: {
        imports = [
          ./modules/common.nix
          ./modules/common-non-darwin.nix
        ];
      };

      acme-sh = import ./modules/acme-sh.nix;
      vault-secrets = import ./modules/vault-secrets.nix;
      serokell-users = import ./modules/serokell-users.nix;
      hackage-search = import ./modules/services/hackage-search.nix;
      nginx = import ./modules/services/nginx.nix;
      upload-daemon = import ./modules/services/upload-daemon.nix;
      hetzner-cloud = import ./modules/virtualization/hetzner-cloud.nix;
      ec2 = import ./modules/virtualization/ec2.nix;
      wireguard-monitoring = import ./modules/wireguard-monitoring/default.nix;
    };
  } // flake-utils.lib.eachDefaultSystem (system:
    # (pinned nix-unstable version does not support aarch64-darwin)
    let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ self.overlay ];
      };
    in with pkgs; {
      devShell = mkShell {
        buildInputs = [ ];
      };
      packages = pkgs.lib.optionalAttrs (! lib.hasInfix "darwin" system) {
        inherit (pkgs) benchwrapper;
      };
    }
  ));
}
