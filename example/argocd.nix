{ transpire, ... }:

{
  namespaces.argocd = {
    helmCharts = {
      argocd = {
        chart = transpire.fetchFromHelm {
          repo = "https://argoproj.github.io/argo-helm";
          name = "argo-cd";
          version = "6.9.2";
          sha256 = "9gwn1+8l40UlsD3UoB6rVrOpF/cVjjJGk8f6WZqllkE=";
        };

        values = { };
      };
    };

    objects = {
      "apps/v1".Deployment.test = { };
    };
  };
}
