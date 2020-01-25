# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

#
# nix-flakes shim
#

let
  sources = builtins.removeAttrs (import ./nix/sources.nix) ["__functor"];
  # https://github.com/input-output-hk/haskell.nix/blob/master/lib/override-with.nix
  tryOverride = override: default:
    let
      try = builtins.tryEval (builtins.findFile builtins.nixPath override);
    in if try.success then
      builtins.trace "using search host <${override}>" try.value
       else
         default;
  overridenSrcs = builtins.mapAttrs (name: s: tryOverride "flake-${name}" s) sources;

  inputs = builtins.mapAttrs (_: s: import s) overridenSrcs;

  # TODO: This is quite terrible. It can be made less terrible by implementing
  # a proper flake import logic with a mutually-recursive attrset.
  adapted = inputs // {
    "haskell-nix" = import ./adapt/haskell-nix.nix {
      haskell-nix-src = overridenSrcs.haskell-nix;
      nixpkgs = inputs.nixpkgs {};
    };
  };

  flake = (import ./flake.nix).outputs (adapted // { self = flake; });
in

flake
