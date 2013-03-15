#!/bin/sh

DOPS_DIR="$(cd "$(dirname "$0")"; pwd)"
git config alias.cipush "!$DOPS_DIR/git-commit-push.sh"

