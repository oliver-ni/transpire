{ lib, stdenvNoCC, kustomize }:

lib.makeOverridable (
  { name
  , kustomization
  , enableHelm ? false
  }:

  stdenvNoCC.mkDerivation {
    name = "kustomize-${name}";
    nativeBuildInputs = [ kustomize ];

    buildCommand = ''
      kustomize build ${kustomization} > $out \
        ${lib.optionalString enableHelm "--enable-helm"} 
    '';
  }
)
