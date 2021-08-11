#!/usr/bin/env bash

# TODO: This script was broken after a refactor of the repository
# Paths and the build process need to be updated

set -euo pipefail
shopt -s inherit_errexit

declare src basedir prog
src="$(realpath "${BASH_SOURCE[0]}")"
basedir="$(dirname "$src")"
prog="$(basename "$src")"

declare -a themes=()
declare -a themes_orig=()
declare -A starred=()

declare -i max_len=0
declare -i scope=0

declare search_query
declare -i search_dir
declare -i search_result

declare status

declare outfile="$basedir/test.yml"

declare tmp
tmp="$(mktemp -p "$basedir" XXXXX.yml)"

function usage() {
  cat >&2 << EOF
usage: $prog [opts] theme [theme ..]

Options:
  -h            display usage information
  -o outfile    output file for generated yaml
EOF
}

function main() {
  local opt OPTIND OPTARG
  while getopts ":ho:" opt "$@"; do
    case "$opt" in
    h)
      usage
      return 0
      ;;
    o)
      outfile="$OPTARG"
      ;;
    \?)
      echo "unknown option: -$OPTARG" >&2
      usage
      return 1
      ;;
    esac
  done

  shift $((OPTIND - 1))

  load_themes "$@"
  themes_orig=("${themes[@]}")

  [[ ${#themes[@]} -gt 0 ]] || {
    usage
    return 1
  }

  local -i i=0
  local -i prev=-1
  local -i sd
  while [[ $i -le ${#themes[@]} ]]; do
    local t="${themes["$i"]}"
    local n
    n="$(basename "$t")"

    menu "$t"

    # purge stdin
    while read -rn 1 -t 0.01 _; do
      true
    done

    if [[ $i -ne $prev ]]; then
      prev=$i
      cat > "$tmp" << EOF
---
_import: !()
  - !? \$import('base.yml')
  - !? \$import('$t')
EOF
      "$basedir/build.sh" "$tmp" "$outfile" &> /dev/null
      rm --preserve-root --one-file-system "$tmp"
    fi

    [[ $scope -eq 1 ]] && echo -n ">" >&2
    echo -n "> " >&2

    local res
    local xres
    read -rsN 1 res
    xres="$(printf '%02x' "'$res")"

    [[ "$xres" == "$(echo -e "\x1b")" ]] && {
      echo >&2
      break
    }

    [[ "$xres" == "1b" ]] && { # esc
      status=
      continue
      # break
    }
    [[ "$xres" == "0a" ]] && { # return
      res="*"
    }
    [[ "$xres" == "7f" ]] && { # backspace
      res="#"
    }

    echo "$res" >&2
    case "$res" in
    g)
      i=0
      ;;
    G)
      i=$((${#themes[@]} - 1))
      ;;
    k | h)
      i=$((i - 1))
      [[ $i -lt 0 ]] && i=$((${#themes[@]} - 1))
      ;;
    j | l)
      i=$((i + 1))
      [[ $i -ge ${#themes[@]} ]] && i=0
      ;;
    c)
      starred=()
      ;;
    "+" | "=" | "}" | "]" | ">")
      [[ ${#starred[@]} -gt 0 ]] || continue
      scope=1
      i=0
      prev=-1
      load_themes "${!starred[@]}"
      starred=()
      ;;
    "-" | "_" | "{" | "[" | "<")
      [[ $scope -eq 1 ]] || continue
      scope=0
      i=0
      prev=-1
      local t
      [[ ${#starred[@]} -eq 0 ]] && {
        starred=()
        for t in "${themes[@]}"; do
          starred["$t"]="$(basename "$t")"
        done
      }
      load_themes "${themes_orig[@]}"
      ;;
    r)
      starred=()
      ;;
    "/")
      sd=1
      ;;&
    "?")
      sd=-1
      ;;&
    "n")
      sd=${search_dir:-1}
      ;;&
    "N")
      sd=$((${search_dir:-1} * -1))
      ;;&
    "/" | "?")
      status=
      menu "$t"
      echo "" >&2
      search_dir=$sd
      search_query="$(prompt_search_query "$res")" || continue
      ;;&
    "/" | "?" | "n" | "N")
      if ((sd == 1)); then
        sc="/"
      else
        sc="?"
      fi
      [[ ! -v search_query || -z "$search_query" ]] && continue
      search_result=$(run_search $sd $i "$search_query") || {
        status="Error: Pattern not found: $search_query"
        continue
      }
      status="$sc$search_query"
      i=$search_result
      ;;
    Q)
      break
      ;;
    " " | "*")
      if [[ -v starred["$t"] && -n "${starred["$t"]}" ]]; then
        unset starred["$t"]
      else
        starred["$t"]="$n"
        echo "*" >&2
      fi
      ;;
    "#")
      if [[ -v starred["$t"] && -n "${starred["$t"]}" ]]; then
        unset starred["$t"]
      fi
      ;;
    esac
    echo
  done

  [[ ${#starred[@]} -gt 0 ]] && {
    echo -e '\nStarred:' >&2
    printf '%s\n' "${!starred[@]}"
    return 0
  }

  [[ $scope -eq 1 && ${#themes[@]} -gt 0 ]] && {
    echo -e '\nStarred:' >&2
    printf '%s\n' "${themes[@]}"
    return 0
  }
}

function run_search() {
  local -i dir=$1
  local -i i=$2
  local query="$3"

  i=$((i + dir))

  local name
  while ((i >= 0 && i < $((${#themes[@]})))); do
    name="$(basename "${themes[$i]}")"
    [[ "$name" =~ $query ]] && {
      echo $i
      return 0
    }
    i=$((i + dir))
  done

  return 1
}

function prompt_search_query() {
  local prefix="$1"

  tput cuu1 >&2
  echo -en "\r" >&2

  local res
  local xres
  local search="${search_query:-}"
  while :; do
    tput el >&2
    echo -en "\r$prefix$search" >&2

    read -rsN 1 res || break
    xres=$(printf '%02x' "'$res")

    [[ "$xres" == "1b" ]] && { # esc
      echo "" >&2
      return 1
    }
    [[ "$xres" == "0a" ]] && { # return
      break
    }
    [[ "$xres" == "7f" ]] && { # backspace
      ((${#search} > 0)) && {
        search="${search:0:-1}"
        tput cub1 >&2
      }
      continue
    }
    [[ "$xres" == "10" ]] && { # C-p
      search="${search_query:-}"
      continue
    }
    [[ "$xres" == "15" || "$xres" == "0b" || "$xres" == "0c" || "$xres" == "0e" ]] && { # C-u, C-k, C-l, C-n
      search=""
      tput el1 >&2
      continue
    }

    search+="$res"
  done

  echo "" >&2
  echo "$search"
  return 0
}

function menu() {
  local theme name nthemes ndigits star prefix
  theme="$1"
  name="$(basename "$theme")"
  nthemes="${#themes[@]}"
  ndigits="${#nthemes}"
  p="$(printf "%0${ndigits}d / %d)" "$((i + 1))" "$nthemes")"
  star=" "
  [[ -v "starred['$theme']" ]] && star="*"
  prefix="$p $name $star"
  {
    printf '%s%s' "$prefix" "$(printf ' %.0s' $(seq ${#prefix} $((max_len + ${#p} + 4))))"
    printf ':%s\n' "${starred[@]}"
  } | column -ts ':' | tac | {
    tput clear
    cat
  } >&2
  [[ -v status && -n "$status" ]] && {
    echo "$status" >&2
  }
  return 0
}

function load_themes() {
  themes=()

  local theme
  while read -r theme; do
    [[ -e "$theme" ]] || {
      echo "no such file: $theme" >&2
      return 1
    }
    theme="$(realpath "$theme")"
    themes+=("$theme")

    local name
    name="$(basename "$theme")"

    ((${#name} > max_len)) && max_len=${#name}
  done <<< "$(sort --general-numeric-sort <<< "$(printf '%s\n' "$@")")"

  return 0
}

function cleanup() {
  if [[ -v tmp && -f "$tmp" ]]; then
    rm --preserve-root --one-file-system "$tmp"
  fi
}

trap 'cleanup' EXIT
main "$@"
