#!/bin/sh
# usage: bootstrap-ssh.sh dir

dir="$1"
ver=20130107

echo "Provisionning bootstrap v$ver in $dir"

has(){
  which "$@" >/dev/null 2>/dev/null
}

warn(){
  echo "$@" >&2
}

if has aptitude; then
  pkgs="git-core"
  ok=true
  for pkg in $pkgs; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      ok=false
      break
    fi
  done
  if ! $ok; then
    aptitude update
    aptitude install -y $pkgs
  fi
elif has yum; then
  pkgs="git"
  ok=true
  for pkg in $pkgs; do
    if ! rpm -q "$pkg" >/dev/null 2>&1; then
      ok=false
      break
    fi
  done
  if ! $ok; then
    yum install -y $pkgs
  fi
else
  echo "Bootstrapping failed: cannot install base packages on unknown system"
fi

if ! has redo; then
  git clone -b simple https://github.com/mildred/redo.git /opt/redo
  ln -s /opt/redo/redo /usr/bin/redo
fi

failed=false
pkgs="git redo"
for bin in $pkgs; do
  if ! has $bin; then
    warn "Bootstrapping failed: $bin not available !"
    failed=true
  fi
done

$failed && return 1

if [ -e "$dir" ]; then
  warn "$dir: already exists"
  exit 1
fi

echo "Create repository in $dir"
mkdir -p "$dir"
cd "$dir"
git init
cat >.git/hooks/post-update <<EOF
git reset --hard
redo
EOF
chmod +x .git/hooks/post-update
git config receive.denyCurrentBranch false
git config receive.denyNonFastForwards false

echo "Bootstrapping done."

exit 0

