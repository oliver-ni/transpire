{
  lib,
  stdenvNoCC,
  kubernetes-helm,
}:

lib.makeOverridable (
  {
    name,
    chart,
    namespace ? null,
    valuesFile ? null,
    includeCRDs ? false,
    skipTests ? true,
    noHooks ? false,
  }:

  stdenvNoCC.mkDerivation {
    name = if chart ? version then "helm-${chart.version}-${name}" else "helm-${name}";
    nativeBuildInputs = [ kubernetes-helm ];

    buildCommand = ''
      helm template ${name} ${chart} \
        ${lib.optionalString (namespace != null) "--namespace ${namespace}"} \
        ${lib.optionalString (valuesFile != null) "--values ${valuesFile}"} \
        ${lib.optionalString includeCRDs "--include-crds"} \
        ${lib.optionalString skipTests "--skip-tests"} \
        ${lib.optionalString noHooks "--no-hooks"} > $out
    '';
  }
)
