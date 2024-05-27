pkgs:

let
  fetchOpenApi = rev: sha256: pkgs.fetchurl {
    inherit sha256;
    url = "https://raw.githubusercontent.com/kubernetes/kubernetes/${rev}/api/openapi-spec/swagger.json";
  };
in
{
  "openapi-v1.30.1" = fetchOpenApi "v1.30.1" "sha256-8r9WCF6db+5Dj8O25VO9VnnmfuUmHPhkyfPiuYzD97Q=";
  "openapi-v1.30.0" = fetchOpenApi "v1.30.0" "sha256-lMp1REFqTyfYyz+KMyYw1BMlxe3rJAilrv43uj/Wr20=";
  "openapi-v1.29.5" = fetchOpenApi "v1.29.5" "sha256-i+n5FLNb9amxKkjZ7H4Wb5wWWiem2NYSZiWQuFiYEeo=";
  "openapi-v1.29.4" = fetchOpenApi "v1.29.4" "sha256-i+n5FLNb9amxKkjZ7H4Wb5wWWiem2NYSZiWQuFiYEeo=";
  "openapi-v1.29.3" = fetchOpenApi "v1.29.3" "sha256-i+n5FLNb9amxKkjZ7H4Wb5wWWiem2NYSZiWQuFiYEeo=";
  "openapi-v1.29.2" = fetchOpenApi "v1.29.2" "sha256-i+n5FLNb9amxKkjZ7H4Wb5wWWiem2NYSZiWQuFiYEeo=";
  "openapi-v1.29.1" = fetchOpenApi "v1.29.1" "sha256-hMILHivO3OHZ0JwD4MywJQDNluYuT6VGUbDpezohEEY=";
  "openapi-v1.29.0" = fetchOpenApi "v1.29.0" "sha256-hMILHivO3OHZ0JwD4MywJQDNluYuT6VGUbDpezohEEY=";
  "openapi-v1.28.9" = fetchOpenApi "v1.28.9" "sha256-z25hoGuWA7AzKlIoIJ1wikdDma1LvVb/M5f0oP1h+5I=";
  "openapi-v1.28.8" = fetchOpenApi "v1.28.8" "sha256-z25hoGuWA7AzKlIoIJ1wikdDma1LvVb/M5f0oP1h+5I=";
  "openapi-v1.28.7" = fetchOpenApi "v1.28.7" "sha256-z25hoGuWA7AzKlIoIJ1wikdDma1LvVb/M5f0oP1h+5I=";
  "openapi-v1.28.6" = fetchOpenApi "v1.28.6" "sha256-z25hoGuWA7AzKlIoIJ1wikdDma1LvVb/M5f0oP1h+5I=";
  "openapi-v1.28.5" = fetchOpenApi "v1.28.5" "sha256-z25hoGuWA7AzKlIoIJ1wikdDma1LvVb/M5f0oP1h+5I=";
  "openapi-v1.28.4" = fetchOpenApi "v1.28.4" "sha256-z25hoGuWA7AzKlIoIJ1wikdDma1LvVb/M5f0oP1h+5I=";
  "openapi-v1.28.3" = fetchOpenApi "v1.28.3" "sha256-z25hoGuWA7AzKlIoIJ1wikdDma1LvVb/M5f0oP1h+5I=";
  "openapi-v1.28.2" = fetchOpenApi "v1.28.2" "sha256-z25hoGuWA7AzKlIoIJ1wikdDma1LvVb/M5f0oP1h+5I=";
  "openapi-v1.28.1" = fetchOpenApi "v1.28.1" "sha256-w9YmRK0xrsphjm9kAXjK85+Re6KWtJGUQ9mDiiKhC+E=";
  "openapi-v1.28.0" = fetchOpenApi "v1.28.0" "sha256-w9YmRK0xrsphjm9kAXjK85+Re6KWtJGUQ9mDiiKhC+E=";
  "openapi-v1.27.9" = fetchOpenApi "v1.27.9" "sha256-L/F1g5VPQJscHtMWFEqmZmoqdfneB0LfBbtmcjsNG5E=";
  "openapi-v1.27.8" = fetchOpenApi "v1.27.8" "sha256-L/F1g5VPQJscHtMWFEqmZmoqdfneB0LfBbtmcjsNG5E=";
  "openapi-v1.27.7" = fetchOpenApi "v1.27.7" "sha256-L/F1g5VPQJscHtMWFEqmZmoqdfneB0LfBbtmcjsNG5E=";
  "openapi-v1.27.6" = fetchOpenApi "v1.27.6" "sha256-L/F1g5VPQJscHtMWFEqmZmoqdfneB0LfBbtmcjsNG5E=";
  "openapi-v1.27.5" = fetchOpenApi "v1.27.5" "sha256-JTQeiuO0Sfr1Eai/xowvbI6Fy932pq1bYdveTY1uDPs=";
  "openapi-v1.27.4" = fetchOpenApi "v1.27.4" "sha256-JTQeiuO0Sfr1Eai/xowvbI6Fy932pq1bYdveTY1uDPs=";
  "openapi-v1.27.3" = fetchOpenApi "v1.27.3" "sha256-JTQeiuO0Sfr1Eai/xowvbI6Fy932pq1bYdveTY1uDPs=";
  "openapi-v1.27.2" = fetchOpenApi "v1.27.2" "sha256-JTQeiuO0Sfr1Eai/xowvbI6Fy932pq1bYdveTY1uDPs=";
  "openapi-v1.27.1" = fetchOpenApi "v1.27.1" "sha256-CaUCxbmBkKPkdgTW34NfI+ejNN+7w/uAcp97ssq/j8Q=";
  "openapi-v1.27.0" = fetchOpenApi "v1.27.0" "sha256-CaUCxbmBkKPkdgTW34NfI+ejNN+7w/uAcp97ssq/j8Q=";
  "openapi-v1.26.9" = fetchOpenApi "v1.26.9" "sha256-kK2FBjBUKr6M7SAAZp7VRyu8t+FtTIz4A6kiRTskVl8=";
  "openapi-v1.26.8" = fetchOpenApi "v1.26.8" "sha256-sXV83p4vIC9Rn9nNhTTD1s9EwzagC1p1+oPj7d/b2Lc=";
  "openapi-v1.26.7" = fetchOpenApi "v1.26.7" "sha256-sXV83p4vIC9Rn9nNhTTD1s9EwzagC1p1+oPj7d/b2Lc=";
  "openapi-v1.26.6" = fetchOpenApi "v1.26.6" "sha256-sXV83p4vIC9Rn9nNhTTD1s9EwzagC1p1+oPj7d/b2Lc=";
  "openapi-v1.26.5" = fetchOpenApi "v1.26.5" "sha256-sXV83p4vIC9Rn9nNhTTD1s9EwzagC1p1+oPj7d/b2Lc=";
  "openapi-v1.26.4" = fetchOpenApi "v1.26.4" "sha256-usXXz179B00xN6Omc4onZk0XVTGY6bolELupRE03D6U=";
  "openapi-v1.26.3" = fetchOpenApi "v1.26.3" "sha256-usXXz179B00xN6Omc4onZk0XVTGY6bolELupRE03D6U=";
  "openapi-v1.26.2" = fetchOpenApi "v1.26.2" "sha256-7z5TrdOH/V9XDVi8rJ89WHFM6N2TmL7nsn01RYOrW2s=";
  "openapi-v1.26.1" = fetchOpenApi "v1.26.1" "sha256-ZZHUuNEhE/vZEmBvM9TRUthFVlYwh3tMZKaWg9LOKfk=";
  "openapi-v1.26.0" = fetchOpenApi "v1.26.0" "sha256-oExcwdy0VzCUDxvUShmDaYMJNFULWYygvM0JYlr13WA=";
}
