#!/bin/echo This script must be sourced
# Usage:
#   self=path/to/bootstrap.sh
#   . $self
if [ -z "$1" ] && [ -z "$self" ]; then
  echo "missing first argument or self variable (path to script itself)"
  return 1
fi

: ${self:=$1}
DIR="$(cd "$(dirname "$self")"; pwd)"
ver=20121206

echo "Provisionning bootstrap v$ver"

has(){
  which "$@" >/dev/null 2>/dev/null
}

warn(){
  echo "$@" >&2
}

if [ -d "$DIR/bin" ]; then
  echo "Adding to PATH: $DIR/bin"
  echo 'PATH="$PATH:$DIR/bin"; export PATH' > /etc/profile.d/provision.sh
  . /etc/profile.d/provision.sh
fi

if has aptitude; then
  pkgs="zeroinstall-injector packagekit policykit-1 git-core"
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
  # aptitude safe-upgrade -y
elif has yum; then
  pkgs="zeroinstall-injector PackageKit git"
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
  git clone https://github.com/apenwarr/redo.git /opt/redo
  ln -s /opt/redo/redo /usr/bin/redo
fi

failed=false
pkgs="pkcon 0launch redo git"
for bin in $pkgs; do
  if ! has $bin; then
    warn "Bootstrapping failed: $bin not available !"
    failed=true
  fi
done

unset self

$failed && return 1

echo "Bootstrapping done."
echo "Available programs: $pkgs"

return 0

