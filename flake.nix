# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{
  description = "Serokell Nix infrastructure library";

  inputs = {
    nixpkgs.url = "github:serokell/nixpkgs";

    # FIXME: new nix has some issues when running in a git repo in detached state
    # for example: https://buildkite.com/serokell/serokell-dot-nix/builds/190#aa2b2fed-4163-442a-a726-9ee1ff3dad9e/78-95
    nix-unstable.url = "github:nixos/nix/79aa7d95183cbe6c0d786965f0dbff414fd1aa67";

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
      nginx = import ./modules/services/nginx.nix;
      upload-daemon = import ./modules/services/upload-daemon.nix;
      hetzner-cloud = import ./modules/virtualization/hetzner-cloud.nix;
      ec2 = import ./modules/virtualization/ec2.nix;
      wireguard-monitoring = import ./modules/wireguard-monitoring.nix;
    };
  } // flake-utils.lib.eachSystem (nixpkgs.lib.remove "aarch64-darwin" flake-utils.lib.defaultSystems) (system:
    # (pinned nix-unstable version does not support aarch64-darwin)
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
        inherit (pkgs) nixUnstable;
      };
  }));
}
