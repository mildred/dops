#!/bin/sh
# usage: bootstrap-self.sh [-n] [--] PROVISIONNING_DIRECTORY [REDO_ARGS...]
# other dops files must be available next to $0


zero="$(basename "$0")"
self_dir="$(cd "$(dirname "$0")"; echo "$PWD")"
usage(){
    echo "Usage: $zero [-h] [-n NODE_ID] [--] [PROVISIONNING_DIRECTORY [REDO_ARGS...]]" >&2
    exit 1
}

run_redo=true
node_id=
while true; do
  case "$1" in
    -h|--help|-help)
      usage
      ;;
    -n)
      node_id="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      break;
  esac
done

if [ $# -ge 1 ]; then
    cd "$1"
    shift
else
    run_redo=false
fi

ver=20130108

node_id_file="$PWD/.git/info/dops_node_id"
if ! [ -s "$node_id_file" ]; then
    echo "Missing node_id in $node_id_file" >&2
    if [ -n "$node_id" ]; then
      echo "Using provided node_id: $node_id" >&2
      echo "$node_id" >"$node_id_file"
    else
      exit 1
    fi
elif [ -n "$node_id" ]; then
  actual_node_id="$(cat "$node_id_file")"
  if [ "x$actual_node_id" != "x$node_id" ]; then
    echo "$node_id_file: $actual_node_id" >&2
    echo "Mismatched with provided node_id: $node_id" >&2
    exit 1
  fi
fi

pkgs_deb="git-core python-setproctitle"
pkgs_rpm="git PackageKit python-setproctitle"
redo_url="https://github.com/mildred/redo.git"
expect_bin="git redo"

. "$self_dir/bootstrap_pkgs.sh"

$failed && return 1

if $run_redo; then
    echo "==> Provisionning"
    if [ $# -eq 0 ]; then
        exec redo provision
    else
        exec redo "$@"
    fi
else
    exit 0
fi

