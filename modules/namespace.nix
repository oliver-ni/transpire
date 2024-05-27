{ name, pkgs, lib, config, transpire, openApiSpec, specialArgs, ... }:

let
  namespace = name;

  objectType = lib.types.nullOr (pkgs.formats.yaml { }).type;
  objectsType = lib.types.attrsOf objectType;
  kindsType = lib.types.attrsOf objectsType;

  helmChartType = lib.types.submoduleWith {
    modules = [ ./helm-chart.nix ];
    inherit specialArgs;
  };

  helmBuildArgs = name: value: {
    inherit name namespace;
    inherit (value) chart valuesFile includeCRDs skipTests noHooks;
  };

  objectToConfig = ({ apiVersion, kind, metadata, ... }@obj: {
    ${apiVersion}.${kind}.${metadata.name} = obj;
  });

  resourcesKey = if openApiSpec != null then "resources" else "objects";
in
{
  imports = [ ./openapi.nix ];

  options = {
    # TODO: Can we somehow generate this? Maybe from the OpenAPI spec?
    objects = lib.mkOption {
      type = lib.types.attrsOf kindsType;
      description = "Attribute set of objects to deploy. Should be in the format <apiVersion>.<kind>.<name> = { ... }.";
      default = { };
    };

    helmReleases = lib.mkOption {
      type = lib.types.attrsOf helmChartType;
      description = "List of Helm charts to deploy.";
      default = { };
    };
  };

  config = {
    ${resourcesKey} = lib.mkMerge (lib.mapAttrsToList
      (name: value:
        lib.pipe (helmBuildArgs name value) [
          transpire.buildHelmChart
          builtins.readFile
          (lib.removeSuffix "\n")
          (lib.splitString "\n")
          (map builtins.fromJSON)
          (map objectToConfig)
          lib.mkMerge
        ])
      config.helmReleases);
  };
}
