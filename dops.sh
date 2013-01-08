DOPS_DIR="$(cd "$(dirname "$0")"; echo $PWD)"

. "$DOPS_DIR/util.sh"

cat <<EOF
: \${DOPS_CONF:=\$PWD/conf}
DOPS_DIR=$(rc_shquote "$DOPS_DIR")
PATH="\$PATH:\$DOPS_DIR/bin"
export DOPS_CONF
export DOPS_DIR
export PATH
EOF
