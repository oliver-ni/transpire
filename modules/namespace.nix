{ name, pkgs, lib, config, transpire, openApiSpec, specialArgs, ... }:

let
  namespace = name;

  objectType = lib.types.nullOr (pkgs.formats.yaml { }).type;
  objectsType = lib.types.attrsOf objectType;
  kindsType = lib.types.attrsOf objectsType;

  helmChartType = lib.types.submoduleWith {
    modules = [ ./helm-release.nix ];
    inherit specialArgs;
  };

  manifestsFromHelm = lib.mapAttrsToList
    (name: value: transpire.buildHelmChart {
      inherit name namespace;
      inherit (value) chart valuesFile includeCRDs skipTests noHooks;
    })
    config.helmReleases;

  manifestsFromKustomize = lib.mapAttrsToList
    (name: path: transpire.buildKustomization {
      inherit name;
      kustomization = path;
    })
    config.kustomizations;

  # Reads one or more documents separated by "---" from a YAML file. Uses IFD.
  readYAMLDocuments = path:
    let
      json = pkgs.runCommand "${path}.yaml" { }
        "${pkgs.yaml2json}/bin/yaml2json < ${lib.escapeShellArg path} > $out";
    in
    lib.pipe json [
      builtins.readFile
      (lib.removeSuffix "\n")
      (lib.splitString "\n")
      (map builtins.fromJSON)
      (builtins.filter (s: s != null))
    ];

  resourcesKey = if openApiSpec != null then "resources" else "objects";

  resourcesFromManifests = lib.mkMerge (map
    ({ apiVersion, kind, metadata, ... }@obj: {
      ${apiVersion}.${kind}.${metadata.name} = obj;
    })
    (builtins.concatMap readYAMLDocuments config.manifests));

  resourcesFromCreateNamespace = lib.mkIf config.createNamespace {
    v1.Namespace."${namespace}" = { };
  };
in
{
  imports = [ ./openapi.nix ];

  options = {
    createNamespace = lib.mkOption {
      type = lib.types.bool;
      description = "Whether to create the v1.Namespace resource.";
      default = false;
    };

    overrideNamespace = lib.mkOption {
      type = lib.types.bool;
      description = "Whether to override metadata.namespace in resources.";
      default = true;
    };

    objects = lib.mkOption {
      type = lib.types.attrsOf kindsType;
      description = "Attribute set of objects to deploy. Should be in the format <apiVersion>.<kind>.<name> = { ... }.";
      default = { };
    };

    manifests = lib.mkOption {
      type = lib.types.listOf lib.types.pathInStore;
      description = "List of raw manifests to parse. Useful for fetching from an external source.";
      default = { };
    };

    helmReleases = lib.mkOption {
      type = lib.types.attrsOf helmChartType;
      description = "Attribute set of Helm charts to deploy.";
      default = { };
    };

    kustomizations = lib.mkOption {
      type = lib.types.attrsOf lib.types.pathInStore;
      description = "Attibute set of kustomizations to deploy.";
      default = { };
    };
  };

  config = {
    manifests = manifestsFromHelm ++ manifestsFromKustomize;

    ${resourcesKey} = lib.mkMerge [
      resourcesFromCreateNamespace
      resourcesFromManifests
    ];
  };
}
