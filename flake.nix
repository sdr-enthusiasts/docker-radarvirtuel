{
  description = "Dev shell and Linting";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    precommit = {
      url = "github:FredSystems/pre-commit-checks";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      precommit,
      ...
    }:
    let
      systems = precommit.lib.supportedSystems;
      inherit (nixpkgs) lib;
    in
    {
      ##########################################################################
      ## PRE-COMMIT CHECKS
      ##########################################################################
      checks = lib.genAttrs systems (system: {
        pre-commit = precommit.lib.mkCheck {
          inherit system;
          src = ./.;

          # ── Feature toggles ─────────────────────────────
          check_rust = false;
          check_docker = true;
          check_python = false;

          # Rust-specific knobs (safe to leave here)
          enableXtask = false;

          # Python-specific knobs (safe to leave here)
          python = {
            enableBlack = true;
            enableFlake8 = true;
          };

          extraExcludes = [
            # Compiled Python bytecode is binary. The text hooks
            # (trailing-whitespace, mixed-line-ending) do not "check"
            # these files, they rewrite them: running them against
            # rootfs/__pycache__/docker-entrypoint.cpython-312.pyc
            # strips 3 bytes, breaks the .pyc magic number and
            # corrupts the marshal payload, so both hooks then report
            # "files were modified by this hook" and fail the run.
            #
            # Linting bytecode is meaningless either way, so exclude it
            # rather than reformatting or deleting the artifact. Scoped
            # to bytecode only, and matched anywhere in the tree so a
            # __pycache__ committed elsewhere cannot reintroduce this.
            "(^|/)__pycache__/"
            "\\.py[co]$"
          ];
        };
      });

      ##########################################################################
      ## DEV SHELL
      ##########################################################################
      devShells = lib.genAttrs systems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          chk = self.checks.${system}.pre-commit;
        in
        {
          default = pkgs.mkShell {
            buildInputs =
              chk.enabledPackages
              ++ (chk.passthru.devPackages or [ ])
              ++ (with pkgs; [
                pre-commit
                check-jsonschema
                codespell
                typos
                nixfmt
                markdownlint-cli2
              ]);

            LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (chk.passthru.libPath or [ ]);

            shellHook = ''
              ${chk.shellHook}
              alias pre-commit="pre-commit run --all-files"
            '';
          };
        }
      );
    };
}
