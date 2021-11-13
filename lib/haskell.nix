{ lib }:

let
  /* Make a Nix flake for a Haskell project.

     The idea is that, given a Haskell project (e.g. a stack project), this function
     will return a flake with packages, checks, and apps, for multiple versions
     of GHC – the ones that you sepcify, plus the “default” one (coming from the
     project configuration, e.g. stack LTS).

     Note that the resulting flake is “naked” in that it does not include the
     system name in its outputs, so you should use `flake-utils` or something.

     * Packages will contain, essentially, everything:
       - Build the library: `nix build .#<package>:lib:<package>`
       - Build an exectuable: `nix build .#<package>:exe:<executable>`
       - Build a test: `nix build .#<package>:test:<test>`
       - Build a benchmark: `nix build .#<package>:bench:<benchmark>`
     * Checks will run corresponding tests:
       - Run a test: `nix check .#<package>:test:<test>`
     * Apps will run corresponding executables:
       - Run a test: `nix run .#<package>:exe:<executable>`

     Everything above can be prefixed with one of the requested GHC versions:

     * Run a test for a specific GHC version:
       - `nix check .#ghc<version>:<package>:test:<test>`

     Inputs:
       - The haskell.nix packages set (i.e. pkgs.haskell-nix)
       - A haskell.nix *Project function (e.g. pkgs.haskell-nix.stackProject)
       - Attrs with:
         - ghcVersions: compiler versions to build with (in addition to the default one)
         - Any other attributes that will be forwarded to the project function

     Example:
       makeFlake pkgs.haskell-nix pkgs.haskell-nix.stackProject {
         src = ./.;
         ghcVersions = [ "901" ];
       }
       =>
       # Assuming you use `flake-utils.lib.eachSystem [ "x86_64-linux" ]`
       $ nix flake show
       <...>
        ├───apps
        │   └───x86_64-linux
        │       ├───"ghc901:package:exe:executable": app
        │       ├───"ghc901:package:test:test": app
        │       ├───"package:exe:executable": app
        │       └───"package:test:test": app
        ├───checks
        │   └───x86_64-linux
        │       ├───"ghc901:package:test:test": derivation 'test-test-1.0.0-check'
        │       └───"package:test:test": derivation 'test-test-1.0.0-check'
        ├───devShell
        │   └───x86_64-linux: development environment 'ghc-shell-for-package'
        └───packages
            └───x86_64-linux
                ├───"ghc901:package:exe:executable": package 'package-exe-executable-1.0.0'
                ├───"ghc901:package:lib:package": package 'package-lib-package-1.0.0'
                ├───"ghc901:package:test:test": package 'test-test-1.0.0'
                ├───"package:exe:executable": package 'package-exe-executable-1.0.0'
                ├───"package:lib:package": package 'package-lib-package-1.0.0'
                └───"package:test:test": package 'test-test-1.0.0'
  */
  makeFlake = haskellNix: projectF: args@{ ghcVersions, ... }:
    let
      args' = builtins.removeAttrs args [ "ghcVersions" ];

      flakeForGhc = ghcVersion:
        let
          compiler-nix-name =
            if ghcVersion == null
            then null
            else "ghc${ghcVersion}";
          project = projectF (args' // { inherit compiler-nix-name; });
          prefix =
              if compiler-nix-name == null
              then ""
              else "${compiler-nix-name}:";
          fixFlakeOutput = name: output:
            if name == "devShell"
            then output
            else lib.mapAttrs' (n: v: lib.nameValuePair (prefix + n) v) output;
          fixFlake =
            lib.mapAttrs fixFlakeOutput;
        in
          fixFlake (project.flake {});

      combineOutputs = name:
        if name == "devShell"
        then lib.last
        else lib.foldl (l: r: l // r) {};

    in lib.zipAttrsWith combineOutputs (map flakeForGhc (ghcVersions ++ [null]));


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
            (optionsLocalPackages = {
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
  inherit makeFlake;

  inherit optionsLocalPackages ciBuildOptions;
}
