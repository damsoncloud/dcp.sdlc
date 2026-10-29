let
  repository = "damsoncloud/dcp.sdlc";
in
{
  scripts.dcp_sdlc_upgrade = {
    description = "Pin GitHub workflows and devenvbase to a ${repository} release, the latest by default, update the devenvbase lock and print the version.";
    exec = ''
      set -euo pipefail
      version="''${1:-$(git ls-remote --tags --refs "https://github.com/${repository}" 'v*.*.*' | sed 's#.*refs/tags/##' | sort -V | tail -n 1)}"
      : "''${version:?no ${repository} release found}"
      cd "$DEVENV_ROOT"
      mapfile -t files < <(git ls-files devenv.yaml '.github/workflows/*.yaml' '.github/workflows/*.yml')
      sed -i -E \
        -e 's#(${repository}/\.github/[^@[:space:]]+)@[^[:space:]]+#\1@'"$version"'#g' \
        -e 's#(github:${repository})(/[^?[:space:]]+)?\?dir=devenvbase#\1/'"$version"'?dir=devenvbase#g' \
        "''${files[@]}"
      devenv update devenvbase >&2
      echo "$version"
    '';
  };
}
