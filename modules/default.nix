{ lib, specialArgs, ... }:

let
  namespace = lib.types.submoduleWith {
    modules = [ ./namespace.nix ];
    inherit specialArgs;
  };
in
{
  options = {
    namespaces = lib.mkOption {
      type = lib.types.attrsOf namespace;
      description = "Namespaces containing scoped objects.";
      default = { };
    };
  };
}
