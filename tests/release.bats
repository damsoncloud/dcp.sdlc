#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load test_helper
  common_setup
}

# Commit a workflow referencing this repository's composite action by the given tag
reference_action() {
  commit_files .github/workflows/release.yaml "      - uses: $DCP_SDLC_REPOSITORY/.github/actions/initialise_devenv@$1"
}

# Print the commit a tag points to
tagged() {
  git rev-parse "$1^{commit}"
}

@test "scripts pass shellcheck" {
  assert_shellcheck release_tag
}

@test "release_tag tags HEAD, moves the major tag and prints only the release tag" {
  tag_versions v1.2.3
  git tag --annotate v1 --message v1
  reference_action v1
  run --separate-stderr release_tag patch
  assert_success
  assert_output v1.2.4
  assert_equal "$(tagged v1.2.4)" "$(git rev-parse HEAD)"
  assert_equal "$(tagged v1)" "$(git rev-parse HEAD)"
  assert_equal "$(git cat-file -t v1.2.4)" tag
}

@test "release_tag releases a major version when workflows reference its major tag" {
  tag_versions v1.2.3
  reference_action v2
  run --separate-stderr release_tag major
  assert_success
  assert_output v2.0.0
  assert_equal "$(tagged v2)" "$(git rev-parse HEAD)"
}

@test "release_tag refuses a major release while workflows reference the previous major tag" {
  tag_versions v1.2.3
  reference_action v1
  run release_tag major
  assert_failure
  assert_output --partial "Workflows must reference this repository's actions with @v2 before releasing v2.0.0"
  run git tag --list v2*
  assert_output ""
}

@test "release_tag fails on an invalid part without tagging" {
  run release_tag
  assert_failure
  run git tag --list
  assert_output ""
}
