{ lib }:

rec {
  # An image derivation is anything exposing `imageName` and `imageTag`, as the
  # `dockerTools` builders in nixpkgs do.
  isImage = value: lib.isDerivation value && value ? imageName && value ? imageTag;

  imageRef = image: "${image.imageName}:${image.imageTag}";

  imageType = lib.types.addCheck lib.types.package isImage // {
    name = "image";
    description = "OCI image derivation";
  };
}
