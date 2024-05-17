{ pkgs, lib, ... }:

let
  resource = (pkgs.formats.yaml { }).type;
  kindGroup = lib.types.attrsOf resource;
  apiVersionGroup = lib.types.attrsOf kindGroup;
in
{
  options = {
    # TODO: Can we somehow generate this? Maybe from the OpenAPI spec?
    objects = lib.mkOption {
      type = lib.types.attrsOf apiVersionGroup;
      description = "Attribute set of objects to deploy. Should be in the format <apiVersion>.<kind>.<name> = { ... }.";
      default = { };
    };
  };

  config = { };
}
