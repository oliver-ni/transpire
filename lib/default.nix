{ callPackage }:

{
  fetchFromHelm = callPackage ./helm/fetch-from-helm.nix { };
  buildChart = callPackage ./helm/build-chart.nix { };
}
