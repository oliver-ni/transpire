{ pkgs, lib, config, ... }:

let
  valuesFormat = pkgs.formats.yaml { };
in
{
  options = {
    chart = lib.mkOption {
      type = lib.types.pathInStore;
      description = "The Helm chart to deploy.";
    };

    values = lib.mkOption {
      type = valuesFormat.type;
      default = { };
      description = "Values to pass to the Helm chart.";
    };

    valuesFile = lib.mkOption {
      type = lib.types.pathInStore;
      description = "A file containing values to pass to the Helm chart. It is recommended to use the `values` option instead.";
    };

    includeCRDs = lib.mkEnableOption "including CRDs in the templated output";
    skipTests = lib.mkEnableOption "skipping tests from templated output";
    noHooks = lib.mkEnableOption "preventing hooks from running during install";
  };

  config = {
    valuesFile = lib.mkDefault (valuesFormat.generate "values.yaml" config.values);
  };
}
