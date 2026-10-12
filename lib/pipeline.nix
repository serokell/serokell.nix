# SPDX-FileCopyrightText: 2022 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{ lib, nixpkgs, deploy-rs }:
rec {
  mkPipeline = { deploy ? { nodes = { }; }, packages ? { }, checks ? { }, deployFromPipeline ? [ ], agents ? [ ]
    , systems ? [ "x86_64-linux" ], ciSystem ? null, nixArgs ? [ ], steps ? { }, validatesWithoutBuild ? true, ... }@args:
    let
      nixArgs' = (if length nixArgs == 0 then "" else " ") + (concatStringsSep " " nixArgs);

      inherit (lib) getAttrFromPath concatStringsSep optionalAttrs optionalString optional optionals escapeShellArg concatLists mapAttrsToList;
      inherit (builtins) concatMap length elemAt listToAttrs mapAttrs attrNames head;

      escapeAttrPath = path: escapeShellArg ''"${concatStringsSep ''"."'' path}"'';

      nixBinPath = system: optionalString (packages ? ${system}.nix) "${packages.${system}.nix}/bin/";

      names = attrs: concatLists (mapAttrsToList (n: v: map (x: [ n x ]) v) (mapAttrs (n: v: attrNames v) attrs));

      filterNative = what: listToAttrs (concatMap (system:
        optional (args ? ${what} && args.${what} ? ${system}) {
          name = system;
          value = args.${what}.${system};
        }) systems);

      makeSteps = what: how: map (p: how ([ what ] ++ p) // { inherit agents; }) (names (filterNative what));

      flakeCheckSteps = optionals (validatesWithoutBuild) (map (system: {
        label = "Check flake (${system})";
        command = "${nixBinPath system}nix flake check --no-build${nixArgs'}";
      }) systems);

      packagesSteps = makeSteps "packages" (path:
        let
          drv = getAttrFromPath path args;
          hasArtifacts = drv ? meta && drv.meta ? artifacts;
        in {
          label = "Build ${elemAt path 2} (${elemAt path 1})";
          command = "${nixBinPath (elemAt path 1)}nix build .#${escapeAttrPath path}${nixArgs'}";
        } // optionalAttrs hasArtifacts {
          artifact_paths = map (art: "result${art}") drv.meta.artifacts;
        });

      shellSteps = makeSteps "devShells" (path: {
        label = "Build devShell ${elemAt path 2} (${elemAt path 1})";
        command = "${nixBinPath (elemAt path 1)}nix build --no-link .#${escapeAttrPath path}${nixArgs'}";
      });

      checkSteps = makeSteps "checks" (path: {
        label = "Check ${elemAt path 2} (${elemAt path 1})";
        command = "${nixBinPath (elemAt path 1)}nix build --no-link .#${escapeAttrPath path}${nixArgs'}";
      });

      impureCheckSteps = makeSteps "steps" (path: {
        label = "Impure check ${elemAt path 2} (${elemAt path 1})";
        command = "eval \"$(nix build --no-link --json .#${escapeAttrPath path}${nixArgs'} | jq -r '.[0].outputs.out')\"";
      });

      doDeploy = { branch, node ? branch, profile, user ? "deploy", ... }: let
        nixArgs'' = (if length nixArgs == 0 then "" else " -- ") + (concatStringsSep " " nixArgs);
      in {
        label = "Deploy ${branch} ${profile}";
        branches = [ branch ];
        command =
          "${deploy-rs.defaultApp.${head systems}.program} ${escapeShellArg ''.#"${node}"."${profile}"''} --ssh-user ${escapeShellArg user} --fast-connection true${nixArgs''}";
        inherit agents;
      };

      deploySteps = [ "wait" ] ++ map doDeploy deployFromPipeline;

      doRelease = {
        label = "Release";
        branches = args.releaseBranches or [ "master" ];
        command = let
          ciSystem' = if ciSystem == null then head systems else ciSystem;
          pkgs = nixpkgs.legacyPackages.${ciSystem'};
        in pkgs.writeShellScript "release" ''
          set -euo pipefail
          export PATH='${pkgs.github-cli}/bin':"$PATH"
          nix build .#'release.${ciSystem'}${nixArgs'}'
          timestamp=$(git show -s --format=%ci)
          date=$(cut -d\  -f1 <<< $timestamp)
          time=$(cut -d\  -f2 <<< $timestamp | sed s/:/-/g)
          gh release create "$date"T"$time" -d -t "Automatic release on $date" -F result/notes.md ./result/*
          sleep 1
          # Clean up old draft releases
          for draft_tag in $(gh release list -L 1000 | grep Draft | tail +${toString ((args.keepReleaseDrafts or 1) + 1)} | cut -f3); do
            gh release delete -y "$draft_tag"
          done
        '';
      };

      releaseSteps = optionals (args ? release) [ "wait" doRelease ];

      steps = flakeCheckSteps ++ packagesSteps ++ shellSteps ++ checkSteps ++ impureCheckSteps ++ releaseSteps ++ deploySteps;
    in { inherit steps; };

  mkPipelineFile = { systems ? [ "x86_64-linux" ], ... }@flake:
    nixpkgs.legacyPackages.${builtins.head systems}.writeText "pipeline.yml"
    (builtins.toJSON (mkPipeline flake));
}
