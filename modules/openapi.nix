{ lib, config, openApiSpec, ... }:

let
  enable = openApiSpec != null;

  spec = builtins.fromJSON (builtins.readFile openApiSpec);

  mkOptionNotRequired = { type, ... }@args: lib.mkOption (args // {
    type = lib.types.nullOr type;
    default = null;
  });

  mkOptionMaybeRequired = required: args:
    let mkFn = if required then lib.mkOption else mkOptionNotRequired;
    in mkFn args;

  # OpenAPI arrays become lists in Nix.
  arrayType = self: def: lib.types.listOf (defType self def.items);

  # If an OpenAPI object has properties, we define a submodule and recursively
  # call `defType` to convert each property definition into a Nix type.
  objectWithPropertiesType = self: def: lib.types.submodule {
    options = lib.mapAttrs
      # FIXME: The top-level `metadata` is populated by the config path, so we
      # make it not required, but this hack also makes nested `metadata` keys
      # not required. We should find a better way to handle this.
      (name: propDef: mkOptionMaybeRequired (name != "metadata" && builtins.elem name (def.required or [ ])) {
        type = defType self propDef;
        description = propDef.description or name;
      })
      def.properties;
  };

  # If an OpenAPI object has additionalProperties, it becomes an attribute set.
  # Otherwise, we call `objectWithPropertiesType` to make a submodule.
  # TODO: Can we support BOTH properties AND additionalProperties?
  objectType = self: def:
    if def ? additionalProperties then lib.types.attrsOf (defType self def.additionalProperties)
    else if def ? properties then objectWithPropertiesType self def
    else lib.types.attrs;

  # Look up references in `self`, which is resolved by `lib.fix`.
  refType = self: ref: self.${lib.removePrefix "#/definitions/" ref};

  defType = self: def:
    let
      type = def.type;
      format = def.format or null;
    in
    if def ? "$ref" then refType self def."$ref"
    else if def ? type then
      if type == "string" then
        if format == "int-or-string" then lib.types.either lib.types.int lib.types.str
        else lib.types.str
      else if type == "integer" then lib.types.int
      else if type == "number" then
        if format == "int32" then lib.types.ints.s32
        else if format == "int64" then lib.types.ints.s64
        else lib.types.number
      else if type == "boolean" then lib.types.bool
      else if type == "array" then arrayType self def
      else if type == "object" then objectType self def
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
if enable then {
  options.resources = (lib.mapAttrs
    (name: value: builtins.listToAttrs value)
    (builtins.groupBy
      (resource: resource.apiVersion)
      resourceDefs));

  config.objects = config.resources;
}
else lib.warn "No OpenAPI spec specified, type-checked `resources` option is turned off." { }
