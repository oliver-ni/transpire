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
        evalModules = pkgs.callPackage ./lib/eval-modules.nix { inherit transpire; };

        # Shortcuts for the most common use cases
        build = {
          __functor = args: (evalModules args).config.build;
          cluster = args: (evalModules args).config.build.cluster;
          clusterFile = args: (evalModules args).config.build.clusterFile;
        };
      });

      packages = forAllSystems (pkgs: transpire: {
        docs = pkgs.callPackage ./docs { inherit transpire; };
      } // import ./generated-openapi-pkgs.nix pkgs);

      apps = forAllSystems (pkgs: transpire: {
        generate-openapi-pkgs = {
          type = "app";
          program = toString (pkgs.writers.writeBash "generate-openapi-pkgs" ''
            git ls-remote --tags --refs --sort="-version:refname" https://github.com/kubernetes/kubernetes |
            awk '{print $2}' |
            while read -r ref; do
              if [[ $ref =~ ^refs/tags/(v[0-9]+\.[0-9]+\.[0-9])+$ ]]; then
                rev="''${BASH_REMATCH[1]}"
                url="https://raw.githubusercontent.com/kubernetes/kubernetes/$rev/api/openapi-spec/swagger.json"
                sha256=$(nix store prefetch-file $url --json | ${pkgs.jq}/bin/jq -r .hash)
                echo "\"openapi-$rev\" = fetchOpenApi \"$rev\" \"$sha256\";"
              fi
            done
          '');
        };
      });
    };
}
