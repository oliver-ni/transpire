{
  pkgs,
  lib,
  config,
  transpire,
  ...
}:

let
  isImage = transpire.imageType.check;

  # nix2container tags carry the image's string context, which would make
  # rendering a manifest build the image.
  imageRef =
    image:
    builtins.unsafeDiscardStringContext "${config.images.registry}/${image.imageName}:${image.imageTag}";

  # Recursively remove any keys where the value is `null` from all nested
  # attrsets, including those in lists. Image derivations are kept intact.
  removeNullRecursive =
    value:
    if isImage value then
      value
    else if builtins.isList value then
      map removeNullRecursive value
    else if builtins.isAttrs value then
      lib.mapAttrs (_: removeNullRecursive) (lib.filterAttrs (_: v: v != null) value)
    else
      value;

  # Recursively replace image derivations with their references.
  renderImages =
    value:
    if isImage value then
      imageRef value
    else if builtins.isList value then
      map renderImages value
    else if builtins.isAttrs value then
      lib.mapAttrs (_: renderImages) value
    else
      value;

  # Recursively collect image derivations.
  collectImages =
    value:
    if isImage value then
      [ value ]
    else if builtins.isList value then
      lib.concatMap collectImages value
    else if builtins.isAttrs value then
      lib.concatMap collectImages (lib.attrValues value)
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

  # Transforms structured config to a list of objects by namespace. Image
  # derivations are kept so that transforms can add or replace them.
  objectsByNs = builtins.mapAttrs (
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
    ) nsModule.objects
  ) (removeNullRecursive config.namespaces);

  rawObjectsByNs = renderImages objectsByNs;
  images = lib.unique (collectImages objectsByNs);

  # Tags default to the store hash of the image, or of its config for layered
  # dockerTools images. Only those tags change with the image contents.
  storeHash = drv: lib.head (lib.splitString "-" (baseNameOf (toString drv)));
  hasDefaultTag = image: image.imageTag == storeHash (image.conf or image.stream.conf or image);

  # A program that copies the image to the skopeo destination given as its
  # argument. nix2container images come with one.
  copyTo =
    image:
    let
      # Layered tarballs inherit `isExe` from their stream, so check the stream.
      source = image.stream or image;
    in
    image.copyTo or (pkgs.writeShellApplication {
      name = "copy-to";
      runtimeInputs = [ pkgs.skopeo ];
      text =
        if source.isExe or false then
          ''${source} | skopeo --insecure-policy copy docker-archive:/dev/stdin "$@"''
        else
          ''skopeo --insecure-policy copy docker-archive:${image} "$@"'';
    });

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
        description = "(Output) Script that builds and pushes the images in `images` to `images.registry` using skopeo. Images with the default tag, a store hash, are skipped if the tag already exists.";
      };
    };
  };

  config.build = rec {
    objects = lib.concatLists (builtins.attrValues rawObjectsByNs);
    namespaces = builtNamespaces;
    cluster = pkgs.linkFarmFromDrvs "cluster" (lib.attrValues namespaces) // {
      inherit images pushImages;
    };
    clusterFile = pkgs.runCommand "cluster.yaml" { } ''
      for i in ${cluster}/*/*.yaml; do
        echo "---" >> $out;
        cat $i >> $out;
      done
    '';
    inherit images;
    pushImages = pkgs.writeShellApplication {
      name = "push-images";
      runtimeInputs = [
        pkgs.jq
        pkgs.skopeo
      ];
      runtimeEnv.PLAN = pkgs.writers.writeJSON "push-images.json" (
        map (image: {
          ref = imageRef image;
          copier = builtins.unsafeDiscardOutputDependency (copyTo image).drvPath;
          skipExisting = hasDefaultTag image;
        }) images
      );
      text = builtins.readFile ./push-images.sh;
    };
  };
}
