{
  description = "Nixe";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils }:
    let
      nixosModule = {config, lib, pkgs,...}:
        let
          cfg = config.services.nixe;
          nixePkg = self.packages.${pkgs.stdenv.hostPlatform.system}.default or pkgs.nixe;
        in {
          options.services.nixe = {
            enable = lib.mkEnableOption "Nixe service";
            port = lib.mkOption {
              type = lib.types.port;
              default = 3000;
              description = "The port to listen on.";
            };
            package = lib.mkOption {
              type = lib.types.package;
              default = nixePkg;
              description = "The nixe package to use.";
            };
          };

          config = lib.mkIf cfg.enable {
            systemd.user.services.nixe = {
              description = "Nixe service";
              wantedBy = [ "default.target" ];
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];
              serviceConfig = {
                Type = "simple";
                ExecStart = "${cfg.package}/bin/nixe";
                Restart = "always";
                RestartSec = 5;
                ProtectSystem = "strict";
                ProtectHome = true;
              };
              environment = {
                PORT = toString cfg.port;
              };
            };
          };
        };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "clippy" ];
        };

        rustPlatform = pkgs.makeRustPlatform {
          cargo = rustToolchain;
          rustc = rustToolchain;
        };

        buildInputs = with pkgs; [
          openssl
          pkg-config
        ] ++ lib.optionals stdenv.isDarwin [
          libiconv
        ];

        nativeBuildInputs = with pkgs; [
          pkg-config
        ];

      in
      {
        packages = {
          default = rustPlatform.buildRustPackage {
            pname = "nixe";
            version = "0.1.0";
            src = ./.;

            cargoLock = {
              lockFile = ./Cargo.lock;
            };

            inherit buildInputs nativeBuildInputs;

            meta = with pkgs.lib; {
              description = "Nixe";
              maintainers = [ ];
            };
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = buildInputs ++ [
            rustToolchain
            pkgs.rust-analyzer
            pkgs.cargo-watch
            pkgs.cargo-edit
          ];

          inherit nativeBuildInputs;

          RUST_SRC_PATH = rustToolchain + "/lib/rustlib/src/rust/library";

          shellHook = ''
            echo "🚀 Rust development environment loaded!"
            echo "Available commands:"
            echo "  cargo run    - Run the application"
            echo "  cargo watch - Watch for changes and rebuild"
            echo "  cargo test   - Run tests"
            echo ""
            echo "The application will be available at http://localhost:3000"
          '';
        };

        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/nixe";
        };
      })//{
        nixosModules.default = nixosModule;
      };
}
