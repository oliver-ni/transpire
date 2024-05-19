{
  description = "Example of a flake that uses transpire-nix";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    transpire.url = "path:..";
  };

  outputs = { flake-utils, transpire, ... }: flake-utils.lib.eachDefaultSystem (system: {
    packages.default = transpire.lib.${system}.build.cluster {
      modules = [ ./cluster ];
    };
  });
}
