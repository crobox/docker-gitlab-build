#!/usr/bin/env bash
set -e

# Run init scripts
. /scripts/init/export-gitlab-ci-container-id.sh

exec "$@"
