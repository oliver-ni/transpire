{ pkgs, lib, config, ... }:

let
  yaml = pkgs.formats.yaml { };

  # Recursively remove any keys where the value is `null` from all nested
  # attrsets, including those in lists.
  removeNullRecursive = value:
    if builtins.isList value then
      map removeNullRecursive value
    else if builtins.isAttrs value then
      lib.filterAttrsRecursive
        (name: value: value != null)
        (lib.mapAttrsRecursive (_: removeNullRecursive) value)
    else value;

  # Like lib.mapAttrsToList, but flattens the resulting list
  concatMapAttrsToList = f: attrs: builtins.concatMap
    (name: f name attrs.${name})
    (builtins.attrNames attrs);

  # Generates a unique filename for an object
  generateFilename = object: "${object.metadata.namespace}_${object.apiVersion}_${object.kind}_${object.metadata.name}.yaml";

  # Adds metadata from the object's config path
  tagObject = { namespace, apiVersion, kind, name, object }: object // {
    inherit apiVersion kind;
    metadata = { inherit namespace name; } // (object.metadata or { });
  };

  # Builds a YAML manifest from an object
  buildObject = (object:
    let obj = lib.pipe (tagObject object) config.transforms;
    in yaml.generate (generateFilename obj) obj);

  # Transform structured config to a list of raw objects by namespace
  builtObjects = builtins.mapAttrs
    (namespace: nsModule: concatMapAttrsToList
      (apiVersion: kinds: concatMapAttrsToList
        (kind: objects: lib.mapAttrsToList
          (name: object: (buildObject { inherit namespace apiVersion kind name object; }))
          objects)
        kinds)
      nsModule.objects)
    (removeNullRecursive config.namespaces);
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
