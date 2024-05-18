{
  description = "Nix-based Kubernetes management";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs = { self, nixpkgs, systems }: {
    evalModules = { pkgs, modules ? [ ], specialArgs ? { } }: pkgs.lib.evalModules {
      modules = [ ./modules/base.nix ./modules/build.nix ] ++ modules;
      specialArgs = {
        inherit pkgs;
        util = {
          fetchFromHelm = pkgs.callPackage ./util/fetch-from-helm.nix { };
          buildHelmChart = pkgs.callPackage ./util/build-helm-chart.nix { };
        };
      } // specialArgs;
    };

    build = {
      __functor = args: (self.evalModules args).config.build;
      cluster = args: (self.evalModules args).config.build.cluster;
      clusterFile = args: (self.evalModules args).config.build.clusterFile;
    };

    packages = nixpkgs.lib.genAttrs (import systems) (system: {
      example = self.build.cluster {
        pkgs = import nixpkgs { inherit system; };
        modules = [ ./example/argocd.nix ];
      };
    });
  };
}
