#!/bin/sh
# usage: bootstrap-ssh.sh remote user@host dir

zero="$(basename "$0")"
usage(){
    echo "Usage: $zero [-f] [--] remote user@host dir" >&2
    exit 1
}

REMOTE_OPTS=
while true; do
  case $1 in
    -f)
      REMOTE_OPTS+=" -f"
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

if [ $# -lt 3 ]; then
    usage
fi

remote="$1"
host="$2"
dir="$3"

DOPS_DIR="$(cd "$(dirname "$0")"; pwd)"

set -x -e

git config alias.cipush "!$DOPS_DIR/git-commit-push.sh"
if git remote | grep "$remote" >/dev/null; then
  git remote rename "$remote" "$remote-$(date '+%Y%m%d-%H%M%S')"
fi
git remote add "$remote" "$host:$dir/.git"

redo "$DOPS_DIR/bootstrap-host.sh"
scp "$DOPS_DIR/bootstrap-host.sh" "$host:/tmp/bootstrap.sh"
if ssh "$host" "sh /tmp/bootstrap.sh $REMOTE_OPTS '$dir'"; then
    set +x +e
    echo
    echo
    echo "$host has been bootstrapped in $dir"
else
    set +x +e
    echo
    echo
    echo "$host was probably already bootstrapped in $dir"
    echo "If you want to force the bootstrapping, re-run this script with -f"
fi

echo "Now, to provision, run:"
echo
echo "    git push $remote master   --  push the current ref for provisionning"
echo "    git cipush $remote master --  commit and push (then revert commit)"
echo

exit 0
