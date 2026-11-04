{
  lib,
  stdenvNoCC,
  kustomize,
}:

lib.makeOverridable (
  {
    name,
    kustomization,
    enableHelm ? false,
  }:

  stdenvNoCC.mkDerivation {
    name = "kustomize-${name}";
    nativeBuildInputs = [ kustomize ];

    buildCommand = ''
      kustomize build ${kustomization} ${lib.optionalString enableHelm "--enable-helm"} > $out
    '';
  }
)
