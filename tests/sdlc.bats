#!/usr/bin/env bats

setup() {
  load test_helper
  common_setup
  stub devenv
}

# Serve the given releases from a local repository instead of the dcp.sdlc GitHub repository
publish_releases() {
  local upstream="$BATS_TEST_TMPDIR/upstream"
  git init --quiet --bare "$upstream"
  git config --global url."$upstream".insteadOf "https://github.com/$DCP_SDLC_REPOSITORY"
  (
    git clone --quiet "$upstream" "$BATS_TEST_TMPDIR/releases"
    cd "$BATS_TEST_TMPDIR/releases" || exit
    if (($#)); then
      tag_versions "$@"
      git push --quiet origin --tags
    fi
  )
}

devenv_yaml() {
  cat <<EOF
inputs:
  devenvbase:
    url: github:$DCP_SDLC_REPOSITORY$1?dir=devenvbase
    flake: false
EOF
}

workflow() {
  cat <<EOF
jobs:
  ci:
    uses: $DCP_SDLC_REPOSITORY/.github/workflows/container-image-ci.yaml@$1
  check:
    steps:
      - uses: actions/checkout@v5
      - uses: $DCP_SDLC_REPOSITORY/.github/actions/initialise_devenv@$1
EOF
}

@test "scripts pass shellcheck" {
  assert_shellcheck dcp_sdlc_version dcp_sdlc_latest dcp_sdlc_upgrade dcp_sdlc_upgrade_pr
}

@test "dcp_sdlc_version prints the release devenvbase is pinned to" {
  commit_files devenv.yaml "$(devenv_yaml /v1.2.3)"
  run dcp_sdlc_version
  assert_success
  assert_output v1.2.3
}

@test "dcp_sdlc_latest prints the highest release" {
  publish_releases v1.9.0 v1.10.0 v2.0 v1
  run dcp_sdlc_latest
  assert_success
  assert_output v1.10.0
}

@test "dcp_sdlc_latest fails without releases" {
  publish_releases
  run dcp_sdlc_latest
  assert_failure
  assert_output --partial "no $DCP_SDLC_REPOSITORY release found"
}

@test "dcp_sdlc_upgrade pins devenvbase and workflows to the release" {
  commit_files devenv.yaml "$(devenv_yaml /v1.0.0)" \
    .github/workflows/cicd.yaml "$(workflow v1.0.0)" \
    .github/workflows/scan.yml "$(workflow main)"
  run dcp_sdlc_upgrade v2.0.0
  assert_success
  assert_output v2.0.0
  assert_equal "$(cat devenv.yaml)" "$(devenv_yaml /v2.0.0)"
  assert_equal "$(cat .github/workflows/cicd.yaml)" "$(workflow v2.0.0)"
  assert_equal "$(cat .github/workflows/scan.yml)" "$(workflow v2.0.0)"
  assert_equal "$(cat "$STUBS/devenv.calls")" "update devenvbase"
}

@test "dcp_sdlc_upgrade pins an unpinned devenvbase and is idempotent" {
  commit_files devenv.yaml "$(devenv_yaml)"
  dcp_sdlc_upgrade v2.0.0
  dcp_sdlc_upgrade v2.0.0
  assert_equal "$(cat devenv.yaml)" "$(devenv_yaml /v2.0.0)"
}

@test "dcp_sdlc_upgrade defaults to the latest release" {
  publish_releases v1.0.0 v2.0.0
  commit_files devenv.yaml "$(devenv_yaml /v1.0.0)"
  run dcp_sdlc_upgrade
  assert_output v2.0.0
  assert_equal "$(cat devenv.yaml)" "$(devenv_yaml /v2.0.0)"
}

@test "dcp_sdlc_upgrade_pr refuses to run with local changes" {
  echo change >file
  run dcp_sdlc_upgrade_pr v2.0.0
  assert_failure
  assert_output --partial "Commit or stash local changes first"
}

setup_origin() {
  git init --quiet --bare "$BATS_TEST_TMPDIR/origin"
  git remote add origin "$BATS_TEST_TMPDIR/origin"
  git push --quiet --set-upstream origin main
  # shellcheck disable=SC2016 # expanded by the stub
  stub gh '[ "$1" = repo ] && echo main || true'
}

@test "dcp_sdlc_upgrade_pr opens a pull request upgrading from the default branch" {
  commit_files devenv.yaml "$(devenv_yaml /v1.0.0)" .github/workflows/cicd.yaml "$(workflow v1.0.0)"
  setup_origin
  git switch --quiet --create feature
  run dcp_sdlc_upgrade_pr v2.0.0
  assert_success
  local branch=chore/dcp-sdlc-v2.0.0 title="chore(deps): upgrade dcp.sdlc to v2.0.0 and update devenv inputs"
  assert_equal "$(git log -1 --format=%s "origin/$branch")" "$title"
  assert_equal "$(git rev-parse "origin/$branch~")" "$(git rev-parse origin/main)"
  assert_equal "$(git show "origin/$branch:devenv.yaml")" "$(devenv_yaml /v2.0.0)"
  assert_equal "$(git show "origin/$branch:.github/workflows/cicd.yaml")" "$(workflow v2.0.0)"
  assert_equal "$(cat "$STUBS/devenv.calls")" $'update devenvbase\nupdate\ntest'
  run grep "^pr create --base main --head $branch --title $title --body " "$STUBS/gh.calls"
  assert_success
}

@test "dcp_sdlc_upgrade_pr does nothing when up to date" {
  commit_files devenv.yaml "$(devenv_yaml /v2.0.0)"
  setup_origin
  run dcp_sdlc_upgrade_pr v2.0.0
  assert_success
  assert_output --partial "Already up to date with $DCP_SDLC_REPOSITORY v2.0.0"
  assert_equal "$(git branch --show-current)" main
  run git branch --list chore/dcp-sdlc-v2.0.0
  assert_output ""
  run grep "^pr " "$STUBS/gh.calls"
  assert_failure
}
