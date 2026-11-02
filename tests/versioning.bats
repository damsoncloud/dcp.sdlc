#!/usr/bin/env bats

setup() {
  load test_helper
  common_setup
}

@test "scripts pass shellcheck" {
  assert_shellcheck version_latest version_bump
}

@test "version_latest prints 0.0.0 without release tags" {
  run version_latest
  assert_success
  assert_output 0.0.0
}

@test "version_latest compares versions numerically and ignores other tags" {
  tag_versions v1.2.3 v1.10.0 v1.9.0 v2 v3.0 latest
  run version_latest
  assert_output 1.10.0
}

@test "version_latest includes tags not reachable from HEAD" {
  git switch --quiet --create release
  tag_versions v1.0.0
  git switch --quiet main
  run version_latest
  assert_output 1.0.0
}

@test "version_bump increases the <major|minor|patch> part of the latest version" {
  tag_versions v1.2.3
  run version_bump major
  assert_output 2.0.0
  run version_bump minor
  assert_output 1.3.0
  run version_bump patch
  assert_output 1.2.4
}

@test "version_bump starts from 0.0.0" {
  run version_bump patch
  assert_output 0.0.1
}

@test "version_bump fails on an invalid part" {
  for argument in "" release; do
    run version_bump "$argument"
    assert_failure
    assert_output --partial "Usage: version_bump <major|minor|patch>"
  done
}
