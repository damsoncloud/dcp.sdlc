let
  repository = "damsoncloud/dcp.sdlc";
  # Name of the devenv input and of its directory in the repository
  devenvbase = "devenvbase";
  name = baseNameOf repository;
in
{
  env.DCP_SDLC_REPOSITORY = repository;

  scripts = {
    dcp_sdlc_version = {
      description = "Print the ${repository} release ${devenvbase} is pinned to.";
      exec = ''
        sed -nE 's#.*github:${repository}/([^?[:space:]]+)\?dir=${devenvbase}.*#\1#p' "$DEVENV_ROOT/devenv.yaml" | head -n 1
      '';
    };

    dcp_sdlc_latest = {
      description = "Print the latest ${repository} release.";
      exec = ''
        set -euo pipefail
        latest=$(git ls-remote --tags --refs "https://github.com/${repository}" 'v*.*.*' | sed 's#.*refs/tags/##' | sort -V | tail -n 1)
        echo "''${latest:?no ${repository} release found}"
      '';
    };

    dcp_sdlc_upgrade = {
      description = "Pin GitHub workflows and ${devenvbase} to a ${repository} release, the latest by default, update the ${devenvbase} lock and print the version.";
      exec = ''
        set -euo pipefail
        version="''${1:-$(dcp_sdlc_latest)}"
        cd "$DEVENV_ROOT"
        mapfile -t files < <(git ls-files devenv.yaml '.github/workflows/*.yaml' '.github/workflows/*.yml')
        sed -i -E \
          -e 's#(${repository}/\.github/[^@[:space:]]+)@[^[:space:]]+#\1@'"$version"'#g' \
          -e 's#(github:${repository})(/[^?[:space:]]+)?\?dir=${devenvbase}#\1/'"$version"'?dir=${devenvbase}#g' \
          "''${files[@]}"
        devenv update ${devenvbase} >&2
        echo "$version"
      '';
    };

    dcp_sdlc_upgrade_pr = {
      description = "Upgrade to a ${repository} release, the latest by default, update all devenv inputs, test and open a pull request.";
      exec = ''
        set -euo pipefail
        cd "$DEVENV_ROOT"
        if [ -n "$(git status --porcelain)" ]; then
          echo "Commit or stash local changes first" >&2
          exit 1
        fi
        version="''${1:-$(dcp_sdlc_latest)}"
        base=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)
        branch="chore/dcp-sdlc-$version"
        git fetch --quiet origin "$base"
        git switch --create "$branch" "origin/$base"
        dcp_sdlc_upgrade "$version" >/dev/null
        devenv update
        if git diff --quiet; then
          echo "Already up to date with ${repository} $version" >&2
          git switch "$base"
          git branch --delete "$branch"
          exit 0
        fi
        devenv test
        message="chore(deps): upgrade ${name} to $version and update devenv inputs"
        git commit --all --message "$message"
        git push --set-upstream origin "$branch"
        gh pr create --base "$base" --head "$branch" --title "$message" \
          --body "Upgrades ${name} to [$version](https://github.com/${repository}/releases/tag/$version) and updates all devenv inputs."
      '';
    };
  };
}
