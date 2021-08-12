#!/usr/bin/env bash
set -euo pipefail

declare base basedir
base="$(realpath "${BASH_SOURCE[0]}")"
basedir="$(realpath -e "$(dirname "$base")/..")"

cd "$basedir"

post_build=""
if [[ $# -gt 0 ]]; then
  post_build="$(printf "'%s' " "$@")"
fi

# shellcheck disable=SC2016,SC1004
find configs -type f -not -regex '.*/base\.yml' \
  | entr -p bash -c '
      basename "$1" \
        | sed "s/\..*$//" \
        | xargs -i sh -c "./scripts/build.sh {}; '"$post_build"'"
    ' -- /_
