{ lib, specialArgs, ... }:

let
  namespaceType = lib.types.submoduleWith {
    modules = [ ./namespace.nix ];
    shorthandOnlyDefinesConfig = true;
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

    transforms = lib.mkOption {
      type = lib.types.listOf (lib.types.functionTo lib.types.attrs);
      description = "Transforms to apply to the objects.";
      default = [ ];
    };

    images.registry = lib.mkOption {
      type = lib.types.str;
      description = "Registry that image derivations are pushed to and referenced from.";
      example = "ghcr.io/example";
    };
  };
}
