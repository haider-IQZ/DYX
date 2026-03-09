{
  description = "DYX - Qt/QML shell with a Zig Axel backend";

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

        runtimePath = lib.makeBinPath (with pkgs; [ axel xdg-utils zenity ]);

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

        dyxQt = pkgs.stdenv.mkDerivation {
          pname = "dyx";
          version = "0.1.0";
          src = cleanedSrc;

          nativeBuildInputs = with pkgs; [
            cmake
            ninja
            pkg-config
            makeWrapper
            qt6.wrapQtAppsHook
          ];

          buildInputs = with pkgs; [
            qt6.qtbase
            qt6.qtdeclarative
            qt6.qtshadertools
            qt6.qtsvg
            qt6.qttools
            qt6.qtwayland
          ];

          configurePhase = ''
            runHook preConfigure
            cmake -S qt -B build/qt -G Ninja -DCMAKE_BUILD_TYPE=Release
            runHook postConfigure
          '';

          buildPhase = ''
            runHook preBuild
            cmake --build build/qt
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            cmake --install build/qt --prefix $out
            mkdir -p $out/libexec
            mv $out/bin/dyx-qt $out/libexec/dyx-qt

            makeWrapper $out/libexec/dyx-qt $out/bin/dyx \
              --set DYX_BACKEND_BIN "${dyxBackend}/libexec/dyx-backend" \
              --prefix PATH : "${runtimePath}" \
              --set-default QT_QUICK_CONTROLS_STYLE Basic
            runHook postInstall
          '';
        };
      in
      {
        packages.default = dyxQt;
        packages.qt = dyxQt;
        packages.backend = dyxBackend;

        apps.default = {
          type = "app";
          program = "${dyxQt}/bin/dyx";
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            axel
            clang
            cmake
            ninja
            pkg-config
            qt6.qtbase
            qt6.qtdeclarative
            qt6.qtshadertools
            qt6.qtsvg
            qt6.qttools
            qt6.qtwayland
            xdg-utils
            zenity
            zig
          ];

          shellHook = ''
            echo "DYX dev shell ready"
            echo "Backend build: zig build backend"
            echo "Backend tests: zig build test"
            echo "Qt configure: cmake -S qt -B build/qt -G Ninja"
            echo "Qt build: cmake --build build/qt"
            echo "Qt run: ./build/qt/dyx-qt"
            echo "Package build: nix build ."
            echo "Package run: nix run ."
            export QT_PLUGIN_PATH="${pkgs.lib.makeSearchPath "lib/qt-6/plugins" [ pkgs.qt6.qtbase pkgs.qt6.qtsvg pkgs.qt6.qtdeclarative ]}"
            export QML2_IMPORT_PATH="${pkgs.qt6.qtdeclarative}/lib/qt-6/qml"
            export QML_IMPORT_PATH="$QML2_IMPORT_PATH"
          '';
        };
      });
}
