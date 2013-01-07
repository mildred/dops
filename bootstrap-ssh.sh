#!/bin/sh
# usage: bootstrap-ssh.sh user@host dir

host="$1"
dir="$2"

scp "$(dirname "$0")/bootstrap-host.sh" "$host:/tmp/bootstrap.sh"
ssh "$host" "sh /tmp/bootstrap.sh '$dir'"

exit 0
