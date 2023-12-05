# SPDX-FileCopyrightText: 2023 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ self, nixpkgs, pkgs, ... }:
import "${nixpkgs}/nixos/tests/make-test-python.nix" ({...} : {
  name = "docker";
  nodes = {
    docker = {...}: {
      imports = [ self.nixosModules.docker ];
      virtualisation.docker = {
        enable = true;
        volumes = [ "thevolume" ];
        networks.thenetwork = {
          driver = "bridge";
          subnet = "172.28.0.0/16";
          ip-range = "172.28.5.0/24";
          gateway = "172.28.5.254";
        };
      };
    };
  };

  testScript = ''
    start_all()

    docker.wait_for_unit("sockets.target")
    docker.wait_for_unit("docker.service")

    docker.succeed("docker volume ls | grep thevolume")
    docker.succeed("docker network ls | grep thenetwork")

    docker.succeed("docker network inspect thenetwork --format {{.IPAM.Config}} | grep '172.28.0.0/16 172.28.5.0/24 172.28.5.254'")

    docker.succeed("docker volume create newvolume");
    docker.succeed("docker network create newnetwork")
    docker.systemctl("restart docker")
    docker.wait_for_unit("docker.service")

    # don't remove manually created networks and volumes
    docker.succeed("docker volume ls | grep newvolume")
    docker.succeed("docker network ls | grep newnetwork")
  '';
}) { inherit pkgs; }
