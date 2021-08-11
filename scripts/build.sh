#!/usr/bin/env bash
set -euo pipefail

declare base basedir
base="$(realpath "${BASH_SOURCE[0]}")"
basedir="$(realpath -e "$(dirname "$base")/..")"

mkdir -p "$basedir/build/configs"
mkdir -p "$basedir/build/tmp"
cd "$basedir/build/tmp"

trap 'rm -rf --preserve-root --one-file-system "$basedir/build/tmp"' EXIT

if [[ ! -d "$basedir/build/themes" ]]; then
  "$basedir/gen-themes.sh"
fi
cp -r "$basedir/build/themes" "$basedir/build/tmp/themes"

declare -a args=()
while read -r config; do
  config_name="$(basename "$config")"
  cp "$config" "$config_name"
  if [[ "$config_name" =~ \.yglu\.ya?ml$ ]]; then
    args+=("$config_name" "$basedir/build/configs/$(sed -E 's/\.yglu\.ya?ml$/.yml/' <<< "$(basename "$config")")")
  fi
done < <(
  if [[ $# -eq 0 ]]; then
    find "$basedir/configs" -type f
  else
    echo "$basedir/configs/base.yml" # TODO: this is hacky
    printf "$basedir/configs/%s.yglu.yml\n" "$@"
  fi
)

yglu-overlay --merge-lists "${args[@]}"
