#!/usr/bin/env bash
# Prints the latest DCP_SDLC_REPOSITORY release.
# Shared by the dcp_sdlc_latest devenv script and the dcp_sdlc_versions composite action.
set -euo pipefail
latest=$(git ls-remote --tags --refs "https://github.com/${DCP_SDLC_REPOSITORY:?}" 'v*.*.*' | sed 's#.*refs/tags/##' | sort -V | tail -n 1)
echo "${latest:?no $DCP_SDLC_REPOSITORY release found}"
