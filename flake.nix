{
  description = "Odin project with Raylib and OLS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        raylibShared = pkgs.raylib.overrideAttrs (old: {
          cmakeFlags = (old.cmakeFlags or []) ++ [
            "-DBUILD_SHARED_LIBS=ON"
            "-DRAYLIB_LIBTYPE=SHARED"
          ];
        });
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            odin
            raylibShared
          ];

          shellHook = ''
            echo "Odin dev shell ready"
            echo "  odin:   $(odin version)"
            # echo "  raylib: ${raylibShared.version}"
          '';
        };
      }
    );
}
