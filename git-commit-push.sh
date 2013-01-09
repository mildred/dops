#!/bin/sh

usage(){
  echo "Usage: git cipush [-a|-h] [--] PUSH_OPTIONS"
  echo "This command runs:"
  echo "    git commit [-a]"
  echo "    git push -f PUSH_OPTIONS"
  echo "    git reset --soft to before the commit"
}

COMMIT_OPTIONS=
while true; do
  case $1 in
    -a)
      COMMIT_OPTIONS+=" -a"
      shift
      ;;
    -h)
      usage >&2
      exit 1
      ;;
    --)
      shift
      break
      ;;
    *)
      break;
  esac
done

HEAD="$(git rev-parse HEAD)"
git commit --allow-empty $COMMIT_OPTIONS -m "Auto-generated commit for provisionning"
echo "HEAD is now $(git rev-parse HEAD)"
(set -x; git -c push.default=simple push -f "$@")
git reset --soft "$HEAD"

