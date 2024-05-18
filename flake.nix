{
  description = "Nix-based Kubernetes management";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      pkgs = import nixpkgs { system = "aarch64-darwin"; };
      transpire = pkgs.callPackage ./lib { };

      result = pkgs.lib.evalModules {
        modules = [
          ./modules/base.nix
          ./modules/build.nix
          ./example/argocd.nix
        ];
        specialArgs = { inherit pkgs transpire; };
      };
    in
    {
      packages.aarch64-darwin.default = result.config.build.cluster;
    };
}
