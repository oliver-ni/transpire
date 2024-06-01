let
  useVaultSecrets = { apiVersion, kind, metadata, ... }@obj:
    if apiVersion == "v1" && kind == "Secret" then
      {
        inherit metadata;
        apiVersion = "secrets.hashicorp.com/v1beta1";
        kind = "VaultStaticSecret";
        spec = {
          type = "kv-v2";
          mount = "kvv2";
          path = "${metadata.namespace}/${metadata.name}";
          destination = {
            inherit (metadata) name;
            create = true;
          };
        };
      }
    else obj;
in
{
  imports = [
    ./guestbook.nix
    ./hedgedoc.nix
  ];

  transforms = [ useVaultSecrets ];
}
