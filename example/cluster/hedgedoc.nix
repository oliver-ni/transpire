{ transpire, ... }:

{
  namespaces.example-hedgedoc = {
    helmCharts.postgres = {
      chart = transpire.fetchFromHelm {
        repo = "https://charts.bitnami.com/bitnami";
        name = "postgresql";
        version = "15.3.3";
        sha256 = "nom+tjaBLxOeuiYM/7XTmMCma3JCiVZ/x/kfXxEmU2Y=";
      };
      values = {
        auth.username = "hedgedoc";
        auth.database = "hedgedoc";
      };
    };

    objects."apps/v1".Deployment.hedgedoc.spec = {
      replicas = 1;
      selector.matchLabels.app = "hedgedoc";
      template = {
        metadata.labels.app = "hedgedoc";
        spec.containers = [{
          name = "hedgedoc";
          image = "quay.io/hedgedoc/hedgedoc:latest";
          ports = [{ containerPort = 3000; }];
          env = [
            { name = "CMD_DB_USERNAME"; value = "hedgedoc"; }
            {
              name = "CMD_DB_PASSWORD";
              valueFrom.secretKeyRef = { name = "postgres-postgresql"; key = "password"; };
            }
            { name = "CMD_DB_DATABASE"; value = "hedgedoc"; }
            { name = "CMD_DB_HOST"; value = "postgres-postgresql"; }
            { name = "CMD_DB_PORT"; value = "5432"; }
            { name = "CMD_DB_DIALECT"; value = "postgres"; }
            { name = "CMD_DOMAIN"; value = "dev-notes.ocf.berkeley.edu"; }
          ];
        }];
      };
    };

    objects.v1.Service.hedgedoc.spec = {
      ports = [{ port = 80; targetPort = 3000; }];
      selector.app = "hedgedoc";
    };

    objects."networking.k8s.io/v1".Ingress.hedgedoc = {
      metadata.annotations = {
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
        "cert-manager.io/cluster-issuer" = "letsencrypt";
      };
      spec = {
        rules = [{
          host = "dev-notes.ocf.berkeley.edu";
          http.paths = [{
            path = "/";
            pathType = "Prefix";
            backend.service = {
              name = "hedgedoc";
              port.number = 80;
            };
          }];
        }];
        tls = [{
          hosts = [ "dev-notes.ocf.berkeley.edu" ];
          secretName = "dev-notes-tls";
        }];
      };
    };
  };
}
