#!/bin/sh
# usage: bootstrap-self.sh [-n] [--] PROVISIONNING_DIRECTORY [REDO_ARGS...]
# other dops files must be available next to $0


zero="$(basename "$0")"
self_dir="$(cd "$(dirname "$0")"; echo "$PWD")"
usage(){
    echo "Usage: $zero [-h] [--] [PROVISIONNING_DIRECTORY [REDO_ARGS...]]" >&2
    exit 1
}

run_redo=true
while true; do
  case "$1" in
    -h|--help|-help)
      usage
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

if ! [ -s "$PWD/.git/info/dops_node_id" ]; then
    echo "Missing node_id in $PWD/.git/info/dops_node_id"
    exit 1
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

