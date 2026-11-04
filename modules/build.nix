{
  pkgs,
  lib,
  config,
  ...
}:

let
  # Recursively drop `null` attributes, including in attrsets nested in lists.
  removeNulls =
    value:
    if builtins.isList value then
      map removeNulls value
    else if builtins.isAttrs value then
      lib.mapAttrs (_: removeNulls) (lib.filterAttrs (_: v: v != null) value)
    else
      value;

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

  # Transforms structured config to a list of raw objects by namespace
  rawObjectsByNs = lib.mapAttrs (
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
    };
  };

  config.build = rec {
    objects = lib.concatLists (lib.attrValues rawObjectsByNs);
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
