while IFS=$'\t' read -r -u3 ref copier skipExisting; do
  if [[ $skipExisting == true ]] && skopeo inspect --raw "docker://$ref" >/dev/null 2>&1; then
    echo "$ref exists, skipping"
    continue
  fi
  "$(nix-store --realise "$copier")/bin/copy-to" "docker://$ref"
done 3< <(jq -r '.[] | [.ref, .copier, .skipExisting] | @tsv' "$PLAN")
