#!/usr/bin/env bash
set -euo pipefail

declare base basedir
base="$(realpath "${BASH_SOURCE[0]}")"
basedir="$(realpath -e "$(dirname "$base")/..")"

cd "$basedir"

if [[ ! -d "$basedir/themes" ]]; then
  echo "$basedir/themes does not exist" >&2
  exit 1
fi

if [[ -d "$basedir/build/themes" ]]; then
  rm -rf "$basedir/build/themes"
fi
mkdir -p "$basedir/build/themes"

# [path]=prefix
declare -A theme_dirs=(
  ["base16-alacritty/colors"]=""
  ["b0o"]=""
)

for dir in "${!theme_dirs[@]}"; do
  prefix="${theme_dirs[$dir]}"
  while read -r theme; do
    filename="$(basename "$theme")"
    name="$(sed -E 's/(-256)?\.yml$//' <<< "$filename")"
    new_filename="${prefix}${filename/\.yaml/.yml}"
    echo "$name" >&2
    cat "$theme" <(echo -e "\nenv:\n  COLORSCHEME: '$name'") > "$basedir/build/themes/$new_filename"
  done < <(find "$basedir/themes/$dir" -type f -regex '.*\.ya?ml$')
done
