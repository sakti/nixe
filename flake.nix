{
  description = "Nixe";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils }:
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

          nixe-service = if pkgs.stdenv.isLinux then pkgs.stdenv.mkDerivation {
            pname = "nixe-service";
            version = "0.1.0";

            dontUnpack = true;

            buildPhase = ''
              mkdir -p $out/lib/systemd/system
              mkdir -p $out/bin

              # Copy the nixe binary
              cp ${self.packages.${system}.default}/bin/nixe $out/bin/

              # Create systemd service file
              cat > $out/lib/systemd/system/nixe.service << EOF
              [Unit]
              Description=Nixe Service
              After=network.target
              Wants=network.target

              [Service]
              Type=simple
              ExecStart=$out/bin/nixe
              Restart=always
              RestartSec=5
              User=nobody
              Group=nobody

              # Security settings
              NoNewPrivileges=yes
              PrivateTmp=yes
              ProtectSystem=strict
              ProtectHome=yes
              ReadWritePaths=/var/lib/nixe

              # Environment
              Environment=RUST_LOG=info

              [Install]
              WantedBy=multi-user.target
              EOF
            '';

            installPhase = ''
              # Files are already in place from buildPhase
            '';

            meta = with pkgs.lib; {
              description = "Nixe systemd service";
              platforms = platforms.linux;
              maintainers = [ ];
            };
          } else pkgs.runCommand "nixe-service-unsupported" {} ''
            mkdir -p $out
            echo "nixe-service is only available on Linux systems" > $out/README
          '';
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
      });
}
