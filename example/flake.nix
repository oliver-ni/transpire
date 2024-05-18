{
  description = "Nix-based Kubernetes management";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    transpire.url = "path:..";
  };

  outputs = { nixpkgs, flake-utils, transpire, ... }: flake-utils.lib.eachDefaultSystem (system: {
    packages.default = transpire.build.cluster {
      pkgs = nixpkgs.legacyPackages.${system};
      modules = [ ./cluster ];
    };
  });
}
