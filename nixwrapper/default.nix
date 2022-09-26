{...}@inputs:
let
  overlay = final: prev: {
    wrappedNix = final.nix.overrideAttrs (oldAttrs: let
      nixcommand = "${final.nix}/bin/nix";
      wrappedNix = prev.writeShellScript "nix" ''
          if [[ "$1" == "run" ]]; then
            shift

            CFLAG=0
            FFLAG=0

            for i in "$@"; do
              if [[ "$i" == "-f"* || "$i" == "--file" ]]; then
                FFLAG=$(($FFLAG+1))
              elif [[ "$i" == "-c"* || "$i" == "--command" ]]; then
                CFLAG=1
                break
              fi
            done

            if [[ $FFLAG -eq 1 && $CFLAG -eq 1 ]]; then
              ${nixcommand} shell "$@"
            else
              ${nixcommand} run "$@"
            fi
          else
            ${nixcommand} "$@"
          fi
      '';

      copyOutputs = final.lib.concatStringsSep "\n" (
        map
        (out: "cp -rs --no-preserve=mode \"${final.nix.${out}}\" \"\$${out}\"")
            # oldAttrs.outputs makes more sense here but... it doesn't work
            prev.nix.outputs
            );
      in
      {
        buildCommand = ''
          ${copyOutputs}
          ln -sf ${wrappedNix} $out/bin/nix
        '';
      });
    };
in { overlays.default = overlay; } //
inputs.flake-utils.lib.eachDefaultSystem (system: {

    # nix flake check
    checks = let
      testpkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [
          (final: prev: {
            nix = prev.writeShellScriptBin "nix" ''
              echo "nix $@"
            '';
          })
          overlay
        ];
      };
      mkTest =
        { name, cmd ? "nix", expected ? cmd }:
        testpkgs.stdenv.mkDerivation {
          inherit name;
          phases = [ name ];
          "${name}" = ''
            nix() {
              ${testpkgs.wrappedNix}/bin/nix "$@"
            }

            output=$(${cmd})

            if [[ ! "$output" == "${expected}" ]]; then
              echo "got :     '$output'"
              echo "expected: '${expected}'"
              exit 1
            else
              touch $out
              echo "✅"
            fi
          '';
        };
    in {
      run-nix-shell-with-flags-simple = mkTest {
        name = "shell_simple";
        cmd = "nix run -f -c";
        expected = "nix shell -f -c";
      };

      nix-shell-advanced = mkTest {
        name = "shell_advcanded";
        cmd = "nix run -f. -c";
        expected = "nix shell -f. -c";
      };

      nix-shell-wildcards = mkTest {
        name = "shell_wildcards";
        cmd = "nix run -f ci.nix pkgs.reuse -c test '**/*'";
        expected = "nix shell -f ci.nix pkgs.reuse -c test **/*";
      };

      nix-shell-specific = mkTest {
        name = "shell_specific";
        cmd = "nix run -f ci.nix pkgs.reuse -c reuse lint";
        expected = "nix shell -f ci.nix pkgs.reuse -c reuse lint";
      };

      nix-run-trivial = mkTest {
        name = "run_trivial";
        cmd = "nix run";
      };

      nix-run-simple = mkTest {
        name = "run_simple";
        cmd = "nix run github:serokell/deploy-rs";
      };

      nix-run-single-flag = mkTest {
        name = "run_single_flag";
        cmd = "nix run -f. legacyPackages.x86_64-linux.haskellPackages.hlint";
      };

      nix-other = mkTest {
        name = "other_nix_command";
        cmd = "nix flake check";
      };
    };
})
