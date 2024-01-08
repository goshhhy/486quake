{
  inputs = {
    nixpkgs.url = "github:ashkitten/nixpkgs/fix-djgpp";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "486quake";
          version = "git";

          src = pkgs.lib.cleanSource ./.;

          nativeBuildInputs = with pkgs; [
            djgpp
          ];

          installPhase = ''
            mkdir $out
            cp build/*.exe $out
          '';
        };

        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            djgpp
          ];
        };
      }
    );
}
