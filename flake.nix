{
  description = "Nix Configuration GUI";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    rnix-lsp.url = "github:nix-community/rnix-lsp";
  };

  outputs = { self, nixpkgs, rnix-lsp, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        nix-dump-cst-json = with pkgs; rustPlatform.buildRustPackage rec {
           pname = "nix_dump_cst_json";
           version = "0.1.0";

           src = ./nix_dump_cst_json;
           cargoHash = "sha256-+mnp3HDYnG/aXNqwxZXmqT2ESnQz7yxDJ5d1M8Yqg0I=";
        };

        pylspclient = pkgs.python3Packages.buildPythonPackage rec {
          pname = "pylspclient";
          version = "0.0.2";
          name = "${pname}-${version}";
          src = builtins.fetchurl {
            url = "https://files.pythonhosted.org/packages/ab/51/d9152f2d86bf8cc2a1dc59be7f9bb771933e26e21e0e96a2bee2547e4a37/pylspclient-0.0.2.tar.gz";
            sha256 = "0ddsf1wx2nq0k80sqsc0q82qd0xhw90z0l791j78fbirfl9gz086";
          };
          doCheck = false;
        };

      in {
        packages.nix-gui = pkgs.callPackage
          ({ stdenv, lib, rustPlatform, fetchFromGitHub }:
            pkgs.python3Packages.buildPythonPackage rec {
              pname = "nix-gui";
              version = "0.1.0";
              src = ./.;
              propagatedBuildInputs = [
                pkgs.python3Packages.pyqt5
                pkgs.python3Packages.parsimonious
                pylspclient
                rnix-lsp.defaultPackage."${system}"
              ];
              makeWrapperArgs = [
                "--prefix PATH : ${nix-dump-cst-json}/bin"
                "--set RUST_LOG trace"
                "--set QT_PLUGIN_PATH ${pkgs.qt5.qtbase}/${pkgs.qt5.qtbase.qtPluginPrefix}"
              ];

              checkInputs = [
                pkgs.python3Packages.pytest
                pkgs.python3Packages.pytest-datafiles
              ];
              checkPhase = "cd nixui && pytest";
            }) { };
        defaultPackage = self.packages.${system}.nix-gui;
        apps.nix-gui = flake-utils.lib.mkApp {
          drv = self.packages."${system}".nix-gui;
        };
        defaultApp = self.apps."${system}".nix-gui;
      }
    );
}
