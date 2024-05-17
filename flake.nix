{
  description = "Nix-based Kubernetes management";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      pkgs = import nixpkgs { system = "aarch64-darwin"; };

      result = pkgs.lib.evalModules {
        modules = [
          ./modules
          ./example/argocd.nix
        ];
        specialArgs = { inherit pkgs; };
      };
    in
    {
      packages.aarch64-darwin.default = (pkgs.formats.yaml { }).generate "output.yaml" result.config;
    };
}
