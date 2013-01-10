#!/bin/bash

usage(){
  echo "Usage: git cipush [-a|-A|-h] PUSH_OPTIONS"
  echo "    -a: Perform git add -u"
  echo "    -a: Perform git add -A"
  echo "This command runs recursively:"
  echo "    git commit --allow-empty -m 'staging area'"
  echo "    git add [-A|-u]"
  echo "    git commit --allow-empty -m 'untracked files'"
  echo "    git push -f PUSH_OPTIONS"
  echo "    git reset --mixed HEAD^"
  echo "    git reset --soft HEAD^"
}

GIT_PUSH_OPTS=()
GIT_PUSH_REPO=

GIT_ADD=
while [ $# -gt 0 ]; do
  case $1 in
    -a)
      GIT_ADD="git add -u"
      shift
      ;;
    -A)
      GIT_ADD="git add -A"
      shift
      ;;
    -h)
      usage >&2
      exit 1
      ;;
    --repo=*)
      GIT_PUSH_OPTS=("${GIT_PUSH_OPTS[@]}" "$1")
      GIT_PUSH_REPO="${1#*=}"
      shift
      ;;
    -*)
      GIT_PUSH_OPTS=("${GIT_PUSH_OPTS[@]}" "$1")
      if [ -n "$GIT_PUSH_REPO" ]; then
        break
      else
        GIT_PUSH_REPO="$1"
        shift
        break
      fi
      ;;
    *)
      break;
  esac
done

GIT_DIR="$(git rev-parse --git-dir)"
export GIT_CIPUSH_TOPLEVEL="$(git rev-parse --show-toplevel)"
cd "$GIT_CIPUSH_TOPLEVEL"

export SCRIPT_COMMIT_STAGING='
  git update-ref OLD_HEAD HEAD
  git submodule foreach --quiet "$SCRIPT_COMMIT_STAGING"
  modpath="$toplevel/$path"
  modpath="${modpath#$GIT_CIPUSH_TOPLEVEL/}"
  cd "$GIT_CIPUSH_TOPLEVEL"
  (set -x; cd "$modpath"; git commit --allow-empty -m "staging area")
  cd "$modpath"
  git update-ref HEAD_STAGING HEAD
'
export SCRIPT_COMMIT_UNTRACKED='
  git submodule foreach --quiet "$SCRIPT_COMMIT_UNTRACKED"
  modpath="$toplevel/$path"
  modpath="${modpath#$GIT_CIPUSH_TOPLEVEL/}"
  cd "$GIT_CIPUSH_TOPLEVEL"
  (set -x; cd "$modpath"; git commit --allow-empty -m "untracked changes")
  cd "$toplevel"
  git add "$path"
  cd "$path"
  git update-ref HEAD_UNTRACKED HEAD
'

warning(){
  echo "WARNING: git-commit-push could not finish" >&2
  echo "WARNING: Your repositories may have extra commits corresponding" >&2
  echo "WARNING: to the staging area and the untracked changes" >&2
}

error(){
  echo "ERROR: git-commit-push was interrupted in a delicate process" >&2
  echo "ERROR: Your tags may have disappeared. They are recoverable in" >&2
  echo "ERROR: refs/cipush-submodules-saved-tags/" >&2
}

trap warning INT

(
  git update-ref OLD_HEAD HEAD

  git submodule foreach --quiet "$SCRIPT_COMMIT_STAGING"
  (set -x; git commit --allow-empty -m "staging area")
  git update-ref HEAD_STAGING HEAD

  if [ -n "$GIT_ADD" ]; then
    (set -x; $GIT_ADD)
    git submodule foreach --quiet --recursive "$GIT_ADD"
  fi

  export COMMIT_MESSAGE="untracked changes"
  git submodule foreach --quiet "$SCRIPT_COMMIT_UNTRACKED"
  (set -x; git commit --allow-empty -m "untracked changes")
  git update-ref HEAD_UNTRACKED HEAD
) >/dev/null 2>&1

echo " $(git rev-parse HEAD) . ($(git describe --all HEAD))"
git submodule status --recursive

cleanupall(){
  cleanup1
  cleanup2
}

cleanup1(){
  echo "Clean up submodules..." >&2
(
  git submodule foreach --recursive --quiet \
    '
    modpath="$toplevel/$path"
    modpath="${modpath#$GIT_CIPUSH_TOPLEVEL/}"
    cd "$GIT_CIPUSH_TOPLEVEL"
    (set -x; cd "$modpath"; git reset --mixed HEAD_UNTRACKED^)
    cd "$modpath"
    '

  git submodule foreach --recursive --quiet \
    '
    modpath="$toplevel/$path"
    modpath="${modpath#$GIT_CIPUSH_TOPLEVEL/}"
    cd "$GIT_CIPUSH_TOPLEVEL"
    (set -x; cd "$modpath"; git reset --soft HEAD_STAGING^)
    cd "$modpath"
    '
) >/dev/null 2>&1
}

cleanup2(){
  echo "Clean up master repository..." >&2
(
  (set -x; git reset --mixed HEAD_UNTRACKED^)
  (set -x; git reset --soft HEAD_STAGING^)
) >/dev/null 2>&1
  trap : INT
}

trap error INT

mv "$GIT_DIR/refs/tags" "$GIT_DIR/refs/cipush-submodules-saved-tags" || exit 1
git submodule foreach --recursive --quiet \
  '
  modpath="$toplevel/$path"
  modpath="${modpath#$GIT_CIPUSH_TOPLEVEL/}"
  git push "$GIT_CIPUSH_TOPLEVEL" "+HEAD_UNTRACKED:refs/tags/submodules/$modpath/HEAD_UNTRACKED" >/dev/null 2>&1
  '
( set -x; git push -f --tags $GIT_PUSH_REPO )
rm -rf "$GIT_DIR/refs/tags"
mv "$GIT_DIR/refs/cipush-submodules-saved-tags" "$GIT_DIR/refs/tags"

trap cleanupall INT
cleanup1

( set -x; git push -f "${GIT_PUSH_OPTS[@]}" "$@" )

cleanup2


