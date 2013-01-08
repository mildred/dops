has(){
  which "$@" >/dev/null 2>/dev/null
}

warn(){
  echo "$@" >&2
}

if has aptitude; then
  ok=true
  for pkg in $pkgs_deb; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      ok=false
      break
    fi
  done
  if ! $ok; then
    aptitude update
    aptitude install -y $pkgs_deb
  fi
elif has yum; then
  pkgs_rpm="git"
  ok=true
  for pkg in $pkgs_rpm; do
    if ! rpm -q "$pkg" >/dev/null 2>&1; then
      ok=false
      break
    fi
  done
  if ! $ok; then
    yum install -y $pkgs_rpm
  fi
else
  echo "Bootstrapping failed: cannot install base packages on unknown system"
fi

if ! has redo; then
  rm -rf /opt/redo
  git clone "$redo_url" /opt/redo
  (
    cd /opt/redo
    ./redo install
  )
fi

failed=false
for bin in $expect_bin; do
  if ! has $bin; then
    warn "Bootstrapping failed: $bin not available !"
    failed=true
  fi
done
