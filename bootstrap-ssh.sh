#!/bin/bash
# usage: bootstrap-ssh.sh remote user@host dir

: ${DOPS_SSH:="$GIT_SSH"}
: ${DOPS_SSH:=ssh}

zero="$(basename "$0")"
usage(){
    echo "Usage: $zero [-f] [-n NODE_ID] [--] REMOTE [USER@HOST DIR]" >&2
    exit 1
}

REMOTE_OPTS=
node_id=
while true; do
  case $1 in
    -f)
      REMOTE_OPTS+=" -f"
      shift
      ;;
    -n)
      node_id="$2"
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      break;
  esac
done

if [ $# != 1 ] && [ $# != 3 ]; then
    usage
fi

remote="$1"
shift

: ${node_id:="$remote"}

if [ $# -ge 1 ]; then
  host="$2"
  dir="$3"
  create_remote=true
else
  url="$(git config "remote.$remote.url")"
  create_remote=false
  host="${url%%:*}"
  dir="${url#*:}"
  dir="${dir%/.git}"
fi

if current_branch="$(git symbolic-ref HEAD 2>/dev/null)"; then
  current_branch="${current_branch#refs/heads/}"
fi

DOPS_DIR="$(cd "$(dirname "$0")"; pwd)"

set -e

git config alias.cipush "!$DOPS_DIR/git-commit-push.sh"
if $create_remote; then
  if git remote | grep "$remote" >/dev/null; then
    git remote rename "$remote" "$remote-$(date '+%Y%m%d-%H%M%S')"
  fi
  git remote add "$remote" "$host:$dir/.git"
fi

redo-ifchange "$DOPS_DIR/bootstrap-host.sh"
if (set -x; "$DOPS_SSH" "$host" "sh -s -- $REMOTE_OPTS '$node_id' '$dir' '$current_branch'" <"$DOPS_DIR/bootstrap-host.sh"); then
    set +e
    echo
    echo "$host has been bootstrapped in $dir"
else
    set +e
    echo
    echo "$host was probably already bootstrapped in $dir"
    echo "If you want to force the bootstrapping, re-run this script with -f"
fi

echo
echo "Now, to provision on the last commit, run:"
echo
echo "    git push -u $remote ${current_branch:-HEAD:master}"
echo
echo "to create a temporary commit and push it, run:"
echo
echo "    git cipush -u $remote ${current_branch:-HEAD:master}"
echo

exit 0
