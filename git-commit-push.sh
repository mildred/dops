#!/bin/sh

usage(){
  echo "git cipush [-a|-h] [--] PUSH_OPTIONS"
}

COMMIT_OPTIONS=
while true; do
  case $1 in
    -a)
      COMMIT_OPTIONS+=" -a"
      shift
      ;;
    -h)
      usage
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
git commit $COMMIT_OPTIONS -m "Auto-generated commit for provisionning"
echo "HEAD is now $(git rev-parse HEAD)"
(set -x; git -c push.default=simple push -f "$@")
git reset --soft "$HEAD"

