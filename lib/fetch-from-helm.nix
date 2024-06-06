{ lib, stdenvNoCC, kubernetes-helm }:

lib.makeOverridable (
  { repo
  , name
  , version
  , sha256 ? lib.fakeSha256
  }:

  stdenvNoCC.mkDerivation {
    pname = "helm-${name}";
    version = version;
    nativeBuildInputs = [ kubernetes-helm ];

    buildCommand = ''
      export HELM_CACHE_HOME="$TMP/.cache"
      helm pull --repo ${repo} ${name} --version ${version} --untar
      mv ${name} $out
    '';

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = sha256;
  }
)
