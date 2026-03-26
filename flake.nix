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

        runtimePath = lib.makeBinPath (with pkgs; [ axel python3 xdg-utils zenity ]);

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
            install -Dm755 zig-out/bin/dyx-native-host $out/libexec/dyx-native-host
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
            mv $out/bin/dyx-relay $out/libexec/dyx-relay
            install -Dm755 ${dyxBackend}/libexec/dyx-native-host $out/libexec/dyx-native-host

            mkdir -p $out/share/dyx/native-messaging/firefox
            install -Dm644 packaging/native-messaging/firefox/app.dyx.native_host.json.in \
              $out/share/dyx/native-messaging/firefox/app.dyx.native_host.json.in

            install -Dm755 scripts/register-firefox-native-host.sh $out/bin/dyx-register-firefox-host
            install -Dm755 scripts/unregister-firefox-native-host.sh $out/bin/dyx-unregister-firefox-host
            patchShebangs $out/bin/dyx-register-firefox-host $out/bin/dyx-unregister-firefox-host

            makeWrapper $out/libexec/dyx-qt $out/bin/dyx \
              --set DYX_BACKEND_BIN "${dyxBackend}/libexec/dyx-backend" \
              --prefix PATH : "${runtimePath}" \
              --set-default QT_QUICK_CONTROLS_STYLE Basic

            wrapProgram $out/bin/dyx-register-firefox-host \
              --set DYX_NATIVE_HOST_BIN "$out/libexec/dyx-native-host" \
              --set DYX_FIREFOX_HOST_TEMPLATE "$out/share/dyx/native-messaging/firefox/app.dyx.native_host.json.in" \
              --prefix PATH : "${lib.makeBinPath (with pkgs; [ coreutils python3 ])}"

            wrapProgram $out/bin/dyx-unregister-firefox-host \
              --prefix PATH : "${lib.makeBinPath (with pkgs; [ coreutils ])}"
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
            python3
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
