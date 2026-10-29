{
  config,
  lib,
  ...
}:

let
  python = config.languages.python;
in
{
  scripts = {
    version_latest = {
      description = "Print the highest released version from `v*` tags, or 0.0.0 without any";
      exec = ''
        latest=$(git -C "$DEVENV_ROOT" tag --list 'v*.*.*' --sort=-v:refname | head -n 1)
        echo "''${latest:-v0.0.0}" | sed 's/^v//'
      '';
    };

    version_bump = {
      description = "Print the latest released version bumped by <major|minor|patch>; uv projects also get it set in pyproject.toml and uv.lock";
      exec = ''
        set -euo pipefail
        IFS=. read -r major minor patch <<<"$(version_latest)"
        case "''${1:-}" in
          major) next="$((major + 1)).0.0" ;;
          minor) next="$major.$((minor + 1)).0" ;;
          patch) next="$major.$minor.$((patch + 1))" ;;
          *) echo "Usage: version_bump <major|minor|patch>" >&2; exit 1 ;;
        esac
        ${lib.optionalString python.uv.enable ''uv version "$next" --no-sync >/dev/null''}
        echo "$next"
      '';
    };
  };
}
