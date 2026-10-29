{
  scripts.release_prepare = {
    description = "Pin this repository's own workflow and action references from @main to a release tag: <tag>";
    exec = ''
      set -euo pipefail
      : "''${1:?Usage: release_prepare <tag>}"
      cd "$DEVENV_ROOT"
      mapfile -t files < <(git ls-files '.github/workflows/*.yaml' '.github/actions/*/action.yml')
      sed -i -E 's#(damsoncloud/dcp\.sdlc/\.github/[^@[:space:]]+)@main#\1@'"$1"'#g' "''${files[@]}"
    '';
  };
}
