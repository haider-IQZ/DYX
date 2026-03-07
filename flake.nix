{
  description = "DYX - a modern Axel desktop app built with Zig and React";

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
                "node_modules"
                "dist"
                "result"
              ]);
        };

        dyxUi = pkgs.buildNpmPackage {
          pname = "dyx-ui";
          version = "0.1.0";
          src = cleanedSrc + "/ui";

          npmDepsHash = "sha256-gCBQcOwxtJXXC7VblTs9BUKwKzgp3AdeJH8h7vjEMHE=";
          npmBuildScript = "build";

          installPhase = ''
            runHook preInstall
            mkdir -p $out
            cp -r dist/. $out/
            runHook postInstall
          '';
        };

        dyx = pkgs.stdenv.mkDerivation {
          pname = "dyx";
          version = "0.1.0";
          src = cleanedSrc;

          nativeBuildInputs = with pkgs; [
            zig
            pkg-config
            clang
            makeWrapper
          ];

          buildInputs = with pkgs; [
            webkitgtk_4_1
            gtk3
          ];

          buildPhase = ''
            runHook preBuild
            zig build -Doptimize=ReleaseSafe
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall

            mkdir -p $out/libexec $out/bin $out/share/dyx/ui/dist
            install -Dm755 zig-out/bin/dyx $out/libexec/dyx
            cp -r ${dyxUi}/. $out/share/dyx/ui/dist/

            cat > $out/bin/dyx <<'EOF'
            #!${pkgs.bash}/bin/bash
            set -euo pipefail

            export DYX_UI_DIST="@out@/share/dyx/ui/dist"
            export PATH="@runtimePath@:$PATH"
            export WEBKIT_DISABLE_DMABUF_RENDERER="''${WEBKIT_DISABLE_DMABUF_RENDERER:-1}"

            if [ -z "''${GDK_BACKEND:-}" ]; then
              if [ "''${DYX_EXPERIMENTAL_WAYLAND:-0}" = "1" ]; then
                export GDK_BACKEND=wayland
              else
                export GDK_BACKEND=x11
              fi
            fi

            exec "@out@/libexec/dyx" "$@"
            EOF
            substituteInPlace $out/bin/dyx \
              --replace-fail "@out@" "$out" \
              --replace-fail "@runtimePath@" "${lib.makeBinPath (with pkgs; [ axel xdg-utils zenity ])}"
            chmod +x $out/bin/dyx

            runHook postInstall
          '';
        };
      in
      {
        packages.default = dyx;
        packages.dyx = dyx;
        packages.ui = dyxUi;

        apps.default = {
          type = "app";
          program = "${dyx}/bin/dyx";
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            axel
            clang
            zenity
            xdg-utils
            nodejs
            pkg-config
            webkitgtk_4_1
            gtk3
            zig
          ];

          shellHook = ''
            echo "DYX dev shell ready"
            echo "Production-style run: zig build run"
            echo "Dev-server run: DYX_UI_DEV_URL=http://127.0.0.1:5173 zig build run"
            echo "Package build: nix build ."
            echo "Wayland opt-in: DYX_EXPERIMENTAL_WAYLAND=1 nix run ."
          '';
        };
      });
}
