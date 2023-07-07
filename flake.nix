{
  description = "A clj-nix flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    maelstrom-src = {
      url = "github:jepsen-io/maelstrom/main";
      flake = false;
    };
    clj-nix = {
      url = "github:jlesquembre/clj-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, maelstrom-src, clj-nix }:
    let
      forAllSystems = function:
        nixpkgs.lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ] (system: function rec {
          inherit system;
          pkgs = nixpkgs.legacyPackages.${system};
          cljpkgs = clj-nix.packages."${system}";
          maelstrom-lock = pkgs.stdenv.mkDerivation {
            name = "maelstrom-lock" ;
            src = maelstrom-src;
            buildInputs = with pkgs; [
              git
            ];
            buildPhase = ''
              ls -lah
              mkdir /tmp/lein-home
              export LEIN_HOME=/tmp/lein-home
              ${cljpkgs.deps-lock}/bin/deps-lock --lein || cat /tmp/*.edn
              cat ./deps-lock.json
            '';
            installPhase = ''
              mkdir $out
              cp ./deps-lock.json $out/deps-lock.json
            '';
            outputHashAlgo = "sha256";
            outputHashMode = "recursive";
            outputHash = "sha256-/qwNeM5mOhNzvE3+tw8Y/z40EQCQXpzzcdCRSWMrvkQ=";
          };
        });
    in
      {
        packages = forAllSystems ({cljpkgs, pkgs, maelstrom-lock, ...}: {
          maelstrom-lock = maelstrom-lock;
          maelstrom = cljpkgs.mkCljBin {
            projectSrc = maelstrom-src;
            name = "maelstrom";
            main-ns = "maelstrom.core";
            # jdkRunner = pkgs.jdk; # This is the default
            lockfile = "${maelstrom-lock}/deps-lock.json";
            buildCommand = ''
              BUILD_DIR="maelstrom"
              export jarPath="$BUILD_DIR/maelstrom.jar"
              mkdir -p $BUILD_DIR
              lein do clean, run doc, uberjar
              cp target/maelstrom-*-standalone.jar "$jarPath"
            '';
            java-opts = [ "-Djava.awt.headless=true" ];
          };
        });
      };

}
