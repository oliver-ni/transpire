{ lib, stdenvNoCC, kubernetes-helm, yq-go }:

lib.makeOverridable (
  { name
  , chart
  , namespace ? null
  , valuesFile ? null
  , includeCRDs ? false
  , skipTests ? false
  , noHooks ? false
  }:

  stdenvNoCC.mkDerivation {
    name = "helm-${chart.version}-${name}";
    nativeBuildInputs = [ kubernetes-helm yq-go ];

    buildCommand = ''
      helm template ${name} ${chart} \
        ${lib.optionalString (namespace != null) "--namespace ${namespace}"} \
        ${lib.optionalString (valuesFile != null) "--values ${valuesFile}"} \
        ${lib.optionalString includeCRDs "--include-crds"} \
        ${lib.optionalString skipTests "--skip-tests"} \
        ${lib.optionalString noHooks "--no-hooks"} \
        | yq -o=json -I=0 > $out
    '';
  }
)
