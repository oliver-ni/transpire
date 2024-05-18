{ lib, specialArgs, ... }:

let
  namespaceType = lib.types.submoduleWith {
    modules = [ ./namespace.nix ];
    inherit specialArgs;
  };
in
{
  options = {
    namespaces = lib.mkOption {
      type = lib.types.attrsOf namespaceType;
      description = "Namespaces containing scoped objects.";
      default = { };
    };
  };
}
