let
  actionReference = "damsoncloud/dcp\\.sdlc/\\.github/actions/[^@[:space:]]+@";
in
{
  scripts.release_tag = {
    description = "Tag HEAD with the latest release bumped by <major|minor|patch>, move the floating major tag to it and print the release tag";
    exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      version=$(version_bump "''${1:-}")
      major="v''${version%%.*}"
      # Reusable workflows reference this repository's actions by the floating major tag, which must match the release
      if git grep -qE '${actionReference}' -- .github/workflows && git grep -E '${actionReference}' -- .github/workflows | grep -vqE "@$major\b"; then
        echo "Workflows must reference this repository's actions with @$major before releasing v$version" >&2
        exit 1
      fi
      git tag --annotate "v$version" --message "Release v$version" >&2
      git tag --force --annotate "$major" --message "Latest $major release: v$version" >&2
      echo "v$version"
    '';
  };
}
