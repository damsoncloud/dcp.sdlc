#!/usr/bin/env bash
# Prints the DCP_SDLC_REPOSITORY release the DCP_SDLC_DEVENVBASE input of devenv.yaml is pinned to.
# Shared by the dcp_sdlc_version devenv script and the dcp_sdlc_versions composite action.
# No pipefail, as head closing the pipe after the first match may fail sed with SIGPIPE
set -eu
sed -nE "s#.*github:${DCP_SDLC_REPOSITORY:?}/([^?[:space:]]+)\?dir=${DCP_SDLC_DEVENVBASE:?}.*#\1#p" "${DEVENV_ROOT:-.}/devenv.yaml" | head -n 1
