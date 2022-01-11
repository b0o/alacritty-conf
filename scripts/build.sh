#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s inherit_errexit
shopt -s failglob

declare base basedir
base="$(realpath "${BASH_SOURCE[0]}")"
basedir="$(realpath -e "$(dirname "$base")/..")"

declare srcdir="$basedir/src"
declare themedir="$srcdir/themes"
declare builddir="$basedir/build"

function resolve_config() {
  local config="$1"
  local p
  for p in "$config" {,"$srcdir/"}"$config" {,"$srcdir/"}"$config"{,.conf}.{yml,yaml}; do
    if [[ -e "$p" ]]; then
      echo "$p"
      return
    fi
  done
  echo "ERROR: not found: $config" >&2
  return 1
}

function json_to_yaml() {
  jq -r '
    def to_yaml:
      (
        .
        | objects
        | to_entries
        | (map(.key | length) | max + 2) as $width
        | .[]
        | (.value | type) as $type
        | if $type == "array" then
            "\(.key):", (.value | to_yaml)
          elif $type == "object" then
            "\(.key):", "    \(.value | to_yaml)"
          else
            "\(.key):\(" " * (.key | $width - length))\(.value | @json)"
          end
      ) // (
        .
        | arrays
        | select(length > 0)
        | .[]
        | [to_yaml]
        | "  - \(.[0])", "    \(.[1:][])"
      ) // .
      ;

    to_yaml
  '
}

function extend() {
  local extend="$1"
  jq --argjson extend "$(yq eval -o json <<<"$extend")" '
    def types($vals):
      .
      | $vals
      | map(type)
      | unique
      ;

    def merge($base):
      .
      | . as $target
      | types([$base, $target]) as $types
      | if $types == ["object"] then
          .
          | reduce (
            .
            | [$base, $target]
            | add
            | keys_unsorted
            | .[]
          ) as $k ({};
            .[$k] = ($target[$k] | merge($base[$k]))
          )
        elif $types == ["array"] then
          $base + $target
        elif $target == null then
          $base
        else
          $target
        end
        ;

        merge($extend)
  ' <<<"$res"
}

function overlay() {
  local overlay="$1"
  jq --argjson overlay "$overlay" '
    .
    | . as $base
    | reduce ($overlay | to_entries | .[]) as $entry ($base;
      .[$entry.key] = $entry.value
      )
  ' <<<"$res"
}

function convert() {
  local res
  res="$(yq eval -o json)"

  local -a imports
  mapfile -t imports < <(jq -cr '."\\{import}" // [] | .[]' <<<"$res")
  res="$(jq -r 'del(."\\{import}")' <<<"$res")"

  local -a extends
  mapfile -t extends < <(jq -cr '."\\{extend}" // [] | .[]' <<<"$res")
  res="$(jq -r 'del(."\\{extend}")' <<<"$res")"

  local -a overlays
  mapfile -t overlays < <(jq -cr '."\\{overlay}" // [] | .[]' <<<"$res")
  res="$(jq -r 'del(."\\{overlay}")' <<<"$res")"

  local theme
  theme="$(jq -cr '."\\{theme}" // empty' <<<"$res")"
  res="$(jq -r 'del(."\\{theme}")' <<<"$res")"

  if [[ -n "$theme" ]]; then
    imports+=("$themedir/$theme")
    extends+=("$(jq --arg theme "$(basename "$theme")" '.env.COLORSCHEME = $theme' <<<'{}')")
  fi

  local import
  for import in "${imports[@]}"; do
    import="$(resolve_config "$import")"
    extends+=("$(cat "$import")")
  done

  local extend
  for extend in "${extends[@]}"; do
    res="$(extend "$extend" <<<"$res")"
  done

  for overlay in "${overlays[@]}"; do
    res="$(overlay "$overlay" <<<"$res")"
  done

  json_to_yaml <<<"$res"
}

function main() {
  mkdir -p "$builddir"

  local config
  local -a configs=("$@")
  if [[ ${#configs[@]} -gt 0 ]]; then
    local -a _configs=("${configs[@]}")
    configs=()
    for config in "${_configs[@]}"; do
      configs+=("$(resolve_config "$config")")
    done
  else
    mapfile -t configs < <(find "$srcdir" -type f -regex '^.*/.*\.conf\.ya?ml$')
  fi

  for config in "${configs[@]}"; do
    local filename name out
    filename="$(basename "$config")"
    name="${filename%%.conf.yaml}"
    name="${name%%.conf.yml}"
    out="$builddir/$name.yml"

    echo "$config..." >&2
    convert <"$config" >"$out"
    echo "  -> $out" >&2
  done
}

main "$@"
