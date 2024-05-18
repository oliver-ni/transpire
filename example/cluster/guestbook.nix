{ util, ... }:

{
  namespaces.example-guestbook = {
    helmCharts.guestbook = {
      chart = util.fetchFromHelm {
        repo = "https://cloudnativeapp.github.io/charts/curated/";
        name = "guestbook";
        version = "0.2.0";
        sha256 = "s9lXIaF9U/Bv1WwnKDummmRGGwKddm7Emr9yFOyjRjw=";
      };
    };
  };
}
