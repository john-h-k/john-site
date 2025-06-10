#!/bin/bash

template_dir="$1"
target_dir="$2"
skeleton="$3"
button_link="$4"
button_text="$5"

if [ "$skeleton" = "default" ]; then
  skeleton="${3:-$(dirname $0)/skeleton.html}"
fi

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
    escaped_button_link="$(printf '%q' "$button_link")"
    escaped_button_text="$(printf '%q' "$button_text")"
    content="$(cat "$output_name.tmp" | tr -d '\n')"

    if [ -n "$button_link" ]; then
      sed -i "s/\[\[BUTTON_LINK\]\]/$escaped_button_link/g" "$output_name"
    fi

    if [ -n "$button_text" ]; then
      sed -i "s/\[\[BUTTON_TEXT\]\]/$escaped_button_text/g" "$output_name"
    fi

    sed -i "s/\[\[TITLE\]\]/$escaped_title/g" "$output_name"
    sed -i "/[[BODY]]/{
      r $output_name.tmp
      d
    }" "$output_name"

    rm "$output_name.tmp"
  fi
done

# NOTE: current main website has its own version of all 3
defaults=(styles.css 404.html not_found.html)
for file in "${defaults[@]}"; do
  if ! [ -e "$target_dir/$file" ]; then
    echo "Copying default '$(dirname "$0")/$file' to '$target_dir/$file'"
    cp "$(dirname "$0")/$file" "$target_dir/$file"
  fi
done
