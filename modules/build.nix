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

  # Recursively drop `null` attributes, keeping image derivations intact.
  removeNulls =
    value:
    if isImage value then
      value
    else if builtins.isList value then
      map removeNulls value
    else if builtins.isAttrs value then
      lib.mapAttrs (_: removeNulls) (lib.filterAttrs (_: v: v != null) value)
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

  collectImages =
    value:
    if isImage value then
      [ value ]
    else if builtins.isList value then
      lib.concatMap collectImages value
    else if builtins.isAttrs value then
      lib.concatMap collectImages (builtins.attrValues value)
    else
      [ ];

  # Flattens `<apiVersion>.<kind>.<name> = object` into a list.
  flattenObjects =
    objects:
    lib.concatLists (
      lib.mapAttrsToList (
        apiVersion: kinds:
        lib.concatLists (
          lib.mapAttrsToList (
            kind:
            lib.mapAttrsToList (
              name: object: {
                inherit
                  apiVersion
                  kind
                  name
                  object
                  ;
              }
            )
          ) kinds
        )
      ) objects
    );

  # Fills in apiVersion, kind and metadata from the object's config path.
  tagObject =
    { namespace, overrideNamespace }:
    {
      apiVersion,
      kind,
      name,
      object,
    }:
    object
    // {
      inherit apiVersion kind;
      metadata = {
        inherit name namespace;
      } // object.metadata or { } // lib.optionalAttrs overrideNamespace { inherit namespace; };
    };

  # Transforms structured config to a list of objects by namespace. Image
  # derivations are kept so that transforms can add or replace them.
  objectsByNs = lib.mapAttrs (
    namespace: nsModule:
    map (
      entry:
      lib.pipe entry (
        [
          (tagObject {
            inherit namespace;
            inherit (nsModule) overrideNamespace;
          })
        ]
        ++ config.transforms
      )
    ) (flattenObjects (removeNulls nsModule.objects))
  ) config.namespaces;

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

  # Generates a unique filename for an object, safe to use unquoted in a shell.
  generateFilename =
    object:
    lib.concatStringsSep "-" (
      builtins.filter builtins.isString (
        builtins.split "[^A-Za-z0-9._-]" (
          "${object.metadata.namespace}_${object.apiVersion}_${object.kind}_${object.metadata.name}.yaml"
        )
      )
    );

  # Each namespace is built by a single derivation that writes all of its
  # objects, since a derivation per object is slow.
  buildObjectCommand =
    object:
    "${lib.getExe pkgs.json2yaml} <<< ${lib.escapeShellArg (builtins.toJSON object)} > $out/${generateFilename object}";

  builtNamespaces = lib.mapAttrs (
    namespace: objects:
    pkgs.runCommand namespace { } ''
      mkdir -p $out
      ${lib.concatMapStringsSep "\n" buildObjectCommand objects}
    ''
  ) rawObjectsByNs;
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
    objects = lib.concatLists (lib.attrValues rawObjectsByNs);
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
