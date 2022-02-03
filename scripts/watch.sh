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
find src -type f \
  | entr -p bash -c '
      basename "$1" \
        | sed "s/\..*$//" \
        | xargs -i sh -c "
            if [[ "{}" == "base" ]]; then
              ./scripts/build.sh
            else
              ./scripts/build.sh {}
            fi
            '"$post_build"'
          "
    ' -- /_
