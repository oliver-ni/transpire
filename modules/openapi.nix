{ lib, ... }:

let
  openapi = ./openapi.json;
  spec = builtins.fromJSON (builtins.readFile openapi);

  # OpenAPI arrays become lists in Nix.
  arrayType = self: def: lib.types.listOf (defType self def.items);

  # If an OpenAPI object has properties, we define a submodule and recursively
  # call `defType` to convert each property definition into a Nix type.
  objectWithPropertiesType = self: def: lib.types.submodule {
    options = (lib.mapAttrs
      (name: propDef: lib.mkOption {
        type =
          if builtins.elem name (def.required or [ ])
          then defType self propDef
          else lib.types.nullOr (defType self propDef);
        description = propDef.description or name;
      })
      def.properties);
  };

  # If an OpenAPI object has additionalProperties, it becomes an attribute set.
  # Otherwise, we call `objectWithPropertiesType` to make a submodule.
  # TODO: Can we support BOTH properties AND additionalProperties?
  # TODO: Look into difference between null and unset
  objectType = self: def:
    if def ? additionalProperties then lib.types.attrsOf (defType self def.additionalProperties)
    else if def ? properties then objectWithPropertiesType self def
    else lib.types.attrs;

  # Look up references in `self`, which is resolved by `lib.fix`.
  refType = self: ref: self.${lib.removePrefix "#/definitions/" ref};

  defType = self: def:
    if def ? "$ref" then refType self def."$ref"
    else if def ? type then
      if def.type == "string" then lib.types.str
      else if def.type == "integer" then lib.types.int
      else if def.type == "number" then
        if def.format == "int32" then lib.types.ints.s32
        else if def.format == "int64" then lib.types.ints.s64
        else lib.types.float
      else if def.type == "boolean" then lib.types.bool
      else if def.type == "array" then arrayType self def
      else if def.type == "object" then objectType self def
      else throw "Unsupported type: ${def.type}"
    else lib.types.anything;

  overridedTypes = {
    # This type recurses on itself, so it will cause a stack overflow.
    "io.k8s.apiextensions-apiserver.pkg.apis.apiextensions.v1.JSONSchemaProps" = lib.types.attrs;
  };

  # Find the fixed point, which is the mapping from each definition name to its
  # converted Nix type. We use `lib.fix` to resolve references recursively.
  defTypes = lib.fix (self: lib.mapAttrs
    (name: def: overridedTypes.${name} or (defType self def))
    spec.definitions);

  # We only care about real resource definitions. These are the ones with POST
  # operations. Also, ensure we have x-kubernetes-group-version-kind.
  resourcePaths = lib.filterAttrs
    (name: path: path ? post
      && path.post.x-kubernetes-action == "post"
      && path.post ? x-kubernetes-group-version-kind)
    spec.paths;

  resourceDefs = lib.mapAttrsToList
    (name: path: rec {
      apiVersion = lib.removePrefix "/" (with path.post.x-kubernetes-group-version-kind; "${group}/${version}");
      name = path.post.x-kubernetes-group-version-kind.kind;
      value = mkResourceOption name (defType defTypes (builtins.head path.post.parameters).schema);
    })
    resourcePaths;

  # This function makes Nix options with corresponding types.
  mkResourceOption = name: type: lib.mkOption {
    type = lib.types.attrsOf type;
    description = "${name} resources";
    default = { };
  };
in
{
  options.resources = lib.mapAttrs
    (name: value: builtins.listToAttrs value)
    (builtins.groupBy
      (resource: resource.apiVersion)
      resourceDefs);
}
