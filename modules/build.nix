{ pkgs, lib, config, ... }:

let
  yaml = pkgs.formats.yaml { };

  # Like lib.mapAttrsToList, but flattens the resulting list
  concatMapAttrsToList = f: attrs: builtins.concatMap
    (name: f name attrs.${name})
    (builtins.attrNames attrs);

  # Generates a unique name for an object
  generateName = object: "${object.metadata.name}_${object.kind}_${object.apiVersion}_${object.metadata.namespace}.yaml";

  # Adds metadata from the object's config path
  transformObject = { namespace, apiVersion, kind, name, object }: object // {
    inherit apiVersion kind;
    metadata = { inherit namespace name; } // (object.metadata or { });
  };

  # Builds a YAML manifest from an object
  buildObject = (object: yaml.generate (generateName object) object);

  # Transform structured config to a list of raw objects by namespace
  builtObjects = builtins.mapAttrs
    (namespace: nsModule: concatMapAttrsToList
      (apiVersion: kinds: concatMapAttrsToList
        (kind: objects: concatMapAttrsToList
          (name: object: lib.optional
            (object != null)
            (buildObject (transformObject { inherit namespace apiVersion kind name object; })))
          objects)
        kinds)
      nsModule.objects)
    config.namespaces;
in
{
  options = {
    build = {
      namespaces = lib.mkOption {
        type = lib.types.attrsOf lib.types.package;
        readOnly = true;
        description = "(Output) YAML objects for each namespace.";
      };
      cluster = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        description = "(Output) All YAML objects, organized by namespace.";
      };
      clusterFile = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        description = "(Output) All YAML objects merged into a single file.";
      };
    };
  };

  config.build = rec {
    namespaces = builtins.mapAttrs pkgs.linkFarmFromDrvs builtObjects;
    cluster = pkgs.linkFarmFromDrvs "cluster" (lib.attrValues namespaces);
    clusterFile = pkgs.runCommand "cluster.yaml" { } ''
      for i in ${cluster}/*/*.yaml; do
        echo "---" >> $out;
        cat $i >> $out;
      done
    '';
  };
}
