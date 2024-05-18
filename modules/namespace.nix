{ name, pkgs, lib, config, transpire, specialArgs, ... }:

let
  namespace = name;

  objectType = (pkgs.formats.yaml { }).type;
  objectsType = lib.types.attrsOf objectType;
  kindsType = lib.types.attrsOf objectsType;

  helmChartType = lib.types.submoduleWith {
    modules = [ ./helm-chart.nix ];
    inherit specialArgs;
  };

  buildChartArgs = name: value: {
    inherit name namespace;
    inherit (value) chart valuesFile includeCRDs skipTests noHooks;
  };

  objectToConfig = ({ apiVersion, kind, metadata, ... }@obj: {
    ${apiVersion}.${kind}.${metadata.name} = obj;
  });
in
{
  options = {
    # TODO: Can we somehow generate this? Maybe from the OpenAPI spec?
    objects = lib.mkOption {
      type = lib.types.attrsOf kindsType;
      description = "Attribute set of objects to deploy. Should be in the format <apiVersion>.<kind>.<name> = { ... }.";
      default = { };
    };

    helmCharts = lib.mkOption {
      type = lib.types.attrsOf helmChartType;
      description = "List of Helm charts to deploy.";
    };
  };

  config = {
    objects = lib.mkMerge (lib.mapAttrsToList
      (name: value:
        lib.pipe (buildChartArgs name value) [
          transpire.buildChart
          builtins.readFile
          (lib.removeSuffix "\n")
          (lib.splitString "\n")
          (map builtins.fromJSON)
          (map objectToConfig)
          lib.mkMerge
        ])
      config.helmCharts);
  };
}
