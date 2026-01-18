{
  description = "Nixe";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils }:
    let
      nixosModule = {config, lib, pkgs,...}: {
        options.service.nixe = {
          enable = lib.mkEnableOption "Nixe";
          port = lib.mkOption {
            type = lib.types.port;
            default = 3000;
            description = "The port to listen on.";
          };
        };
        config = lib.mkIf config.service.nixe.enable {
          systemd.services.nixe = {
            description = "Nixe";
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "simple";
              ExecStart = "${self.packages.${pkgs.system}.default}/bin/nixe";
              Restart = "always";
              RestartSec = 5;
            };
            environment = {
              PORT = toString config.service.nixe.port;
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
