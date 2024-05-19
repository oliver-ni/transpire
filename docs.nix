{ lib
, stdenvNoCC
, nixosOptionsDoc
, mkdocs
, python3Packages
, transpire
, ...
}:

let
  eval = transpire.evalModules {
    modules = [{
      options._module.args = lib.mkOption { internal = true; };
      config._module.check = false;
    }];
  };
  optionsDoc = nixosOptionsDoc { inherit (eval) options; };
in
stdenvNoCC.mkDerivation {
  name = "transpire-nix-docs";
  src = ./.;

  nativeBuildInputs = [
    mkdocs
    python3Packages.mkdocs-material
  ];

  buildPhase = ''
    mkdir -p docs
    cat ${optionsDoc.optionsCommonMark} > docs/index.md
    mkdocs build
  '';

  installPhase = ''
    mv site $out
  '';
}
