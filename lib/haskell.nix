{ nixpkgs, lib, getTestedWithVersions }:

let
  makeCI = haskellPkgs: {
    # haskell project root
    src,
    # list of ghc versions to build packages, if not specified the ghc versions
    # will be taken from tested-with stanzas from .cabal files
    ghcVersions ? [],
    # whether to build the project with stack, disable if you are not using stack
    buildWithStack ? true,
    # stack files to use in addition to stack.yaml
    stackFiles ? [],
    # stack resolvers for building the project, they will be replaced in stack.yaml
    resolvers ? [],
    # extra haskell.nix arguments
    extraArgs ? {}
  }:
    # if buildWithStack is false, there is no point in specifying resolvers or stackFiles
    assert !buildWithStack -> resolvers == [] && stackFiles == [];
    let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    replaceDots = builtins.replaceStrings ["."] ["-"];
    cabalFiles = lib.filter (x: x != "") (lib.splitString "\n"
      (builtins.readFile (pkgs.runCommand "cabalFiles" {} ''
        ${pkgs.findutils}/bin/find ${src} -type f -name "*.cabal" > $out
      '')));

    # extract ghc tested-with versions from each .cabal file, keep a list of packages built with each ghc
    ghc-versions-tested-with = let
      # ghc versions for each package
      ghcsPerCabal = map (f: {
        package = lib.removeSuffix ".cabal" (builtins.baseNameOf f);
        ghcs = getTestedWithVersions f;}) cabalFiles;
      # ghc versions from all .cabal files
      allGhcs = lib.unique (lib.concatMap (lib.getAttr "ghcs") ghcsPerCabal);
    in lib.genAttrs allGhcs
      (ghc: map (lib.getAttr "package") (lib.filter (attrs: builtins.elem ghc attrs.ghcs) ghcsPerCabal));
    ghc-versions = if ghcVersions != [] then ghcVersions else lib.attrNames ghc-versions-tested-with;
    # invoke haskell.nix for every ghc specified in tested-with stanzas of .cabal files
    pkgs-per-ghc = let
      pkgs' = lib.genAttrs ghc-versions
        (ghc: haskellPkgs.haskell-nix.cabalProject ({
          inherit src;
          compiler-nix-name = ghc;
        } // extraArgs));
      # we need to filter out packages and checks that are not specified to build with this compiler
      filterFlake' = ghc: flake': flake' // {
        packages = filterPackages ghc flake'.packages;
        checks = filterPackages ghc flake'.checks;
      };
      filterPackages = ghc: packages: lib.filterAttrs
        (n: _: builtins.elem (lib.head (lib.splitString ":" n)) ghc-versions-tested-with.${ghc}) packages;
    in if ghcVersions != [] then pkgs'
       else lib.flip lib.mapAttrs pkgs' (n: v: v // { flake' = filterFlake' n v.flake';});

    # invoke haskell.nix for stack.yaml and every file from stackFiles
    stackYamls = lib.optionals buildWithStack ([ "stack.yaml" ] ++ stackFiles);
    pkgs-per-stack-yaml = lib.mapAttrs' (n: v: lib.nameValuePair (replaceDots n) v)
      (lib.genAttrs stackYamls
        (stackYaml: haskellPkgs.haskell-nix.stackProject {
          inherit src stackYaml;
        } // extraArgs));

    # invoke haskell.nix for every resolver specified in resolvers
    stackResolvers = lib.optionals buildWithStack resolvers;
    pkgs-per-resolver = lib.mapAttrs' (n: v: lib.nameValuePair (replaceDots n) v)
      (lib.genAttrs stackResolvers
        (resolver: haskellPkgs.haskell-nix.stackProject {
          src = pkgs.runCommand "change resolver" { } ''
            mkdir -p $out
            cp -rT ${src} $out
            ${pkgs.gnused}/bin/sed -i 's/resolver:.*/resolver: ${resolver}/' $out/stack.yaml
          '';
        } // extraArgs));

    all-pkgs = pkgs-per-ghc // pkgs-per-stack-yaml // pkgs-per-resolver;

    # all components for each specified ghc version or stack yaml
    build-all = lib.mapAttrs' (prefix: pkg:
      lib.nameValuePair "${prefix}:build-all"
        (pkgs.linkFarmFromDrvs "build-all" (lib.attrValues pkg.flake'.packages))) all-pkgs;

    # all tests for each specified ghc version or stack yaml
    test-all = lib.mapAttrs' (prefix: pkg:
      lib.nameValuePair "${prefix}:test-all"
        (pkgs.linkFarmFromDrvs "test-all" (lib.attrValues pkg.flake'.checks))) all-pkgs;

    # build matrix used in github actions
    build-matrix = { include = map (prefix: { inherit prefix; }) (ghc-versions ++ (map replaceDots (stackYamls ++ stackResolvers))); };

  in {
    inherit build-all test-all build-matrix all-pkgs;
  };

  /* Set haskell.nix package config options for all project (local) packages.

     This is similar to `$local` in stack.yaml in that it applies only
     to packages that are part of the current project.
     Unlike in stack.yaml, you can set any haskell.nix options here.

     Input: attrset of configuration options to set.
     Output: a module that you add to the `modules` list when building a project.

     Example:
       pkgs.haskell-nix.stackProject {
          # <...>
          modules = [
            (optionsLocalPackages {
              ghcOptions = [ "-Werror" ];
            })
          ];
       };
  */
  optionsLocalPackages = values: { lib, ... }: {
    # XXX: Oh boy, is this a hack!
    #      A clean solution is currently impossible: https://github.com/input-output-hk/haskell.nix/issues/1282
    #      This hack is from: https://github.com/input-output-hk/haskell.nix/issues/298#issuecomment-767936405
    options.packages = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
        config = lib.mkIf config.package.isLocal values;
      }));
    };
  };

  /* Set project build options suitable for a CI build.

     This will:
       - Enable `-Werror` for project packages.
       - Build Haddock for project packages only.

     Example:
       pkgs.haskell-nix.stackProject {
          <...>
          modules = [
            ciBuildOptions
          ];
       };
  */
  ciBuildOptions = {
    imports =
      [ (optionsLocalPackages {
          ghcOptions = [ "-Werror" ];
          doHaddock = true;
        })
      ];
    config = {
      doHaddock = false;
    };
  };

in {
  inherit makeCI ciBuildOptions optionsLocalPackages;
}
