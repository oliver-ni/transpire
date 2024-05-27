{ pkgs, transpire }:

{ modules ? [ ]
, specialArgs ? { }
, openApiSpec ? null
}:

pkgs.lib.evalModules {
  modules = [ ../modules/base.nix ../modules/build.nix ] ++ modules;
  specialArgs = { inherit pkgs transpire openApiSpec; } // specialArgs;
}
