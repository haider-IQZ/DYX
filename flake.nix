{
  description = "DYX - Tauri + Next frontend with a Zig Axel backend";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;

        cleanedSrc = builtins.path {
          path = ./.;
          name = "dyx-src";
          filter = path: type:
            let
              base = builtins.baseNameOf path;
            in
              !(lib.elem base [
                ".git"
                ".direnv"
                ".zig-cache"
                "zig-out"
                "build"
                "result"
                "node_modules"
                ".next"
                "out"
                "target"
              ]);
        };

        runtimePath = lib.makeBinPath (with pkgs; [
          axel
          xdg-utils
          zenity
        ]);

        dyxFrontend = pkgs.buildNpmPackage {
          pname = "dyx-frontend";
          version = "0.1.0";
          src = cleanedSrc;
          npmDepsHash = "sha256-3AhIBanCzRRY2jwvNK23BmCO6Kl9C9bCk0xHqQsaZ6E=";
          npmBuildScript = "build";

          installPhase = ''
            runHook preInstall
            mkdir -p $out
            cp -r out/. $out/
            runHook postInstall
          '';
        };

        dyxBackend = pkgs.stdenv.mkDerivation {
          pname = "dyx-backend";
          version = "0.1.0";
          src = cleanedSrc;

          nativeBuildInputs = with pkgs; [
            zig
            pkg-config
            clang
          ];

          buildPhase = ''
            runHook preBuild
            zig build backend -Doptimize=ReleaseSafe
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            mkdir -p $out/libexec
            install -Dm755 zig-out/bin/dyx-backend $out/libexec/dyx-backend
            runHook postInstall
          '';
        };

        dyxTauri = pkgs.rustPlatform.buildRustPackage {
          pname = "dyx";
          version = "0.1.0";
          src = cleanedSrc;
          cargoRoot = "src-tauri";
          cargoLock.lockFile = ./src-tauri/Cargo.lock;

          nativeBuildInputs = with pkgs; [
            pkg-config
            makeWrapper
          ];

          buildInputs = with pkgs; [
            gtk3
            openssl
            webkitgtk_4_1
          ];

          preBuild = ''
            rm -rf ../out
            cp -r ${dyxFrontend} ../out
          '';

          postInstall = ''
            mkdir -p $out/libexec
            install -Dm755 target/release/dyx-tauri $out/libexec/dyx-tauri

            makeWrapper $out/libexec/dyx-tauri $out/bin/dyx \
              --set DYX_BACKEND_BIN "${dyxBackend}/libexec/dyx-backend" \
              --prefix PATH : "${runtimePath}" \
              --set-default WEBKIT_DISABLE_DMABUF_RENDERER 1 \
              --run 'if [ -z "''${GDK_BACKEND:-}" ] && [ "''${DYX_EXPERIMENTAL_WAYLAND:-0}" != "1" ]; then export GDK_BACKEND=x11; fi'
          '';
        };
      in
      {
        packages.default = dyxTauri;
        packages.tauri = dyxTauri;
        packages.backend = dyxBackend;
        packages.frontend = dyxFrontend;

        apps.default = {
          type = "app";
          program = "${dyxTauri}/bin/dyx";
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            axel
            cargo
            clang
            nodejs
            openssl
            pkg-config
            rustc
            cargo-tauri
            webkitgtk_4_1
            gtk3
            xdg-utils
            zenity
            zig
          ];

          shellHook = ''
            echo "DYX dev shell ready"
            echo "Backend build: zig build backend"
            echo "Backend tests: zig build test"
            echo "Frontend dev: npm run dev"
            echo "Tauri dev: npm run tauri:dev"
            echo "Package build: nix build ."
            echo "Package run: nix run ."
            echo "Wayland opt-in: DYX_EXPERIMENTAL_WAYLAND=1 npm run tauri:dev"
          '';
        };
      });
}
