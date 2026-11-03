{ lib }:

# An image derivation is anything exposing `imageName` and `imageTag`, as the
# `dockerTools` builders in nixpkgs do.
lib.types.addCheck lib.types.package (value: value ? imageName && value ? imageTag)
// {
  name = "image";
  description = "OCI image derivation";
}
