{
  pkgs,
  lib,
  config,
  transpire,
  ...
}:

let
  # Recursively drop `null` attributes and replace image derivations with
  # their references.
  toRawValue =
    value:
    if transpire.isImage value then
      transpire.imageRef value
    else if builtins.isList value then
      map toRawValue value
    else if builtins.isAttrs value then
      lib.mapAttrs (_: toRawValue) (lib.filterAttrs (_: v: v != null) value)
    else
      value;

  collectImages =
    value:
    if transpire.isImage value then
      [ value ]
    else if builtins.isList value then
      lib.concatMap collectImages value
    else if builtins.isAttrs value then
      lib.concatMap collectImages (builtins.attrValues value)
    else
      [ ];

  # Like lib.mapAttrsToList, but flattens the resulting list
  concatMapAttrsToList =
    f: attrs: builtins.concatMap (name: f name attrs.${name}) (builtins.attrNames attrs);

  # Adds metadata from the object's config path
  tagObject =
    { overrideNamespace }:
    {
      namespace,
      apiVersion,
      kind,
      name,
      object,
    }:
    let
      metadata =
        if overrideNamespace then
          { inherit name; } // (object.metadata or { }) // { inherit namespace; }
        else
          { inherit name namespace; } // (object.metadata or { });
    in
    object // { inherit apiVersion kind metadata; };

  # Transforms structured config to a list of raw objects by namespace
  rawObjectsByNs = builtins.mapAttrs (
    namespace: nsModule:
    concatMapAttrsToList (
      apiVersion: kinds:
      concatMapAttrsToList (
        kind: objects:
        lib.mapAttrsToList (
          name: object:
          lib.pipe (tagObject { inherit (nsModule) overrideNamespace; } {
            inherit
              namespace
              apiVersion
              kind
              name
              object
              ;
          }) config.transforms
        ) objects
      ) kinds
    ) (toRawValue nsModule.objects)
  ) config.namespaces;

  images = lib.unique (
    lib.concatMap (nsModule: collectImages nsModule.objects) (builtins.attrValues config.namespaces)
  );

  # Streaming builders produce an executable that writes the archive to stdout;
  # the others produce the archive itself. `buildLayeredImage` inherits `isExe`
  # from its stream despite producing an archive, so check the output name too.
  isStream =
    image: (image.isExe or false) && builtins.match ".*\\.tar(\\.[a-z0-9]+)?" image.name == null;

  pushImageCommand =
    image:
    let
      dest = "docker://${transpire.imageRef image}";
    in
    if isStream image then
      ''${image} | skopeo --insecure-policy copy "$@" docker-archive:/dev/stdin ${dest}''
    else
      ''skopeo --insecure-policy copy "$@" docker-archive:${image} ${dest}'';

  # Generates a unique filename for an object
  generateFilename =
    object:
    "${object.metadata.namespace}_${object.apiVersion}_${object.kind}_${object.metadata.name}.yaml";

  # To create the output derivations, we generate a command for each object.
  # Then, for every namespace, we join these commands into a single script that
  # builds all objects in that namespace.

  # Originally, we used `pkgs.formats.yaml` to generate the YAML files and 
  # `pkgs.linkFarmFromDrvs` to create the output derivations. However, that 
  # created a derivation for each object, which was slow.

  pathEscape =
    text:
    builtins.concatStringsSep "-" (
      builtins.filter builtins.isString (builtins.split "[^A-Za-z0-9._-]" text)
    );

  buildObjectCommand =
    object:
    let
      filename = generateFilename object;
      value = builtins.toJSON object;
    in
    "${pkgs.json2yaml}/bin/json2yaml <<< ${lib.escapeShellArg value} > $out/'${pathEscape filename}'";

  buildCommandsByNs = builtins.mapAttrs (namespace: map buildObjectCommand) rawObjectsByNs;

  builtNamespaces = builtins.mapAttrs (
    namespace: commands:
    pkgs.runCommand namespace { } ''
      mkdir -p $out
      ${builtins.concatStringsSep "\n" commands}
    ''
  ) buildCommandsByNs;
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
      images = lib.mkOption {
        type = lib.types.listOf transpire.imageType;
        readOnly = true;
        description = "(Output) Image derivations referenced by any object.";
      };
      pushImages = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        description = "(Output) Script that pushes every image in `images` to its registry with skopeo. Extra arguments are passed to `skopeo copy`.";
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
    inherit images;
    pushImages = pkgs.writeShellApplication {
      name = "push-images";
      runtimeInputs = [ pkgs.skopeo ];
      text = lib.concatLines (map pushImageCommand images);
    };
  };
}
