{ pkgs, lib, config, ... }:

let
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

  # Adds metadata from the object's config path
  tagObject = { namespace, apiVersion, kind, name, object }: object // {
    inherit apiVersion kind;
    metadata = { inherit namespace name; } // (object.metadata or { });
  };

  # Transforms structured config to a list of raw objects by namespace
  rawObjectsByNs = builtins.mapAttrs
    (namespace: nsModule: concatMapAttrsToList
      (apiVersion: kinds: concatMapAttrsToList
        (kind: objects: lib.mapAttrsToList
          (name: object: lib.pipe
            (tagObject { inherit namespace apiVersion kind name object; })
            config.transforms)
          objects)
        kinds)
      nsModule.objects)
    (removeNullRecursive config.namespaces);

  # Generates a unique filename for an object
  generateFilename = object: "${object.metadata.namespace}_${object.apiVersion}_${object.kind}_${object.metadata.name}.yaml";

  # To create the output derivations, we generate a command for each object.
  # Then, for every namespace, we join these commands into a single script that
  # builds all objects in that namespace.

  # Originally, we used `pkgs.formats.yaml` to generate the YAML files and 
  # `pkgs.linkFarmFromDrvs` to create the output derivations. However, that 
  # created a derivation for each object, which was slow.

  pathEscape = text: builtins.replaceStrings [ "/" "'" "\"" "<" ">" ] [ "-" "-" "-" "-" "-" ] text;

  buildObjectCommand = object:
    let
      filename = generateFilename object;
      value = builtins.toJSON object;
    in
    "${pkgs.json2yaml}/bin/json2yaml <<< ${lib.escapeShellArg value} > $out/'${pathEscape filename}'";

  buildCommandsByNs = builtins.mapAttrs
    (namespace: map buildObjectCommand)
    rawObjectsByNs;

  builtNamespaces = builtins.mapAttrs
    (namespace: commands: pkgs.runCommand namespace { } ''
      mkdir -p $out
      ${builtins.concatStringsSep "\n" commands}
    '')
    buildCommandsByNs;
in
{
  options = {
    build = {
      objects = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        readOnly = true;
        description = "(Output) List of all raw objects.";
      };
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
    objects = lib.concatLists (builtins.attrValues rawObjectsByNs);
    namespaces = builtNamespaces;
    cluster = pkgs.linkFarmFromDrvs "cluster" (lib.attrValues namespaces);
    clusterFile = pkgs.runCommand "cluster.yaml" { } ''
      for i in ${cluster}/*/*.yaml; do
        echo "---" >> $out;
        cat $i >> $out;
      done
    '';
  };
}
