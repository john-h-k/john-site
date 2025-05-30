#!/bin/bash

template_dir="$1"
target_dir="$2"
skeleton="${3:-$(dirname $0)/skeleton.html}"

mkdir -p "$target_dir"

echo "Reading templates from '$template_dir' and generating into '$target_dir' (skeleton '$skeleton')"

for file in $(find "$template_dir" -type f -not -path '*/.*'); do
  full_name=$(realpath --relative-to "$template_dir" -- "$file")
  mkdir -p "$(dirname -- "$target_dir/$full_name")"

  # non markdown files simply get copied over

  if [[ "$file" != *.md ]]; then
    output_name="$target_dir/$full_name"
    echo "Copying '$full_name' into '$output_name'"

    cp "$file" "$output_name"
  else
    full_name=$(realpath --relative-to "$template_dir" -- "$file")
    title="${full_name%.md}"
    output_name="$target_dir/$title.html"

    if [[ "$title" == "README" ]]; then
      output_name="$target_dir/index.html"
    fi

    cp "$skeleton" "$output_name"
  
    echo "Processing '$full_name' into '$output_name'"

    tail -n +2 < "$file" | jq --slurp --raw-input  '{"text": "\(.)", "mode": "gfm"}'\
      | gh api \
          --method POST \
          -H "Accept: application/vnd.github+json" \
          -H "X-GitHub-Api-Version: 2022-11-28" \
          --input - \
          /markdown \
        > "$output_name.tmp"
  
    title="$(head -1 "$file" | sed 's/^ *# *//')"
    escaped_title="$(printf '%q' "$title")"
    content="$(cat "$output_name.tmp" | tr -d '\n')"

    sed -i "s/\[\[TITLE\]\]/$escaped_title/g" "$output_name"
    sed -i "/[[BODY]]/{
      r $output_name.tmp
      d
    }" "$output_name"

    rm "$output_name.tmp"
  fi
done

# copy default CSS if not provided
if ! [ -e "$target_dir/styles.css" ]; then
  echo "Copying '$(dirname "$0")/styles.css' to '$target_dir/styles.css'"
  cp "$(dirname "$0")/styles.css" "$target_dir/styles.css"
fi
