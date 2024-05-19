{
  description = "Nix-based Kubernetes management";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs = { self, nixpkgs, systems }:
    let
      withLib = fn: pkgs: fn pkgs self.lib.${pkgs.system};
      forAllSystems = fn: nixpkgs.lib.genAttrs
        (import systems)
        (system: withLib fn nixpkgs.legacyPackages.${system});
    in
    {
      lib = forAllSystems (pkgs: transpire: rec {
        fetchFromHelm = pkgs.callPackage ./lib/fetch-from-helm.nix { };
        buildHelmChart = pkgs.callPackage ./lib/build-helm-chart.nix { };

        evalModules = { modules ? [ ], specialArgs ? { } }: pkgs.lib.evalModules {
          modules = [ ./modules/base.nix ./modules/build.nix ] ++ modules;
          specialArgs = { inherit pkgs transpire; } // specialArgs;
        };

        build = {
          __functor = args: (evalModules args).config.build;
          cluster = args: (evalModules args).config.build.cluster;
          clusterFile = args: (evalModules args).config.build.clusterFile;
        };
      });

      packages = forAllSystems (pkgs: transpire: {
        docs = pkgs.callPackage ./docs.nix { inherit transpire; };
      });
    };
}
