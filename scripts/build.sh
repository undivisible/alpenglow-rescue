#!/bin/sh
# Default development path: the actual pinned Alpenglow fast base.
# Rescue payload integration is still pending; this is not a rescue ISO.
set -eu
exec sh "$(dirname "$0")/build-fast-base.sh"
