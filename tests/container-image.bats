#!/usr/bin/env bats

setup() {
  load test_helper
  common_setup
  stub podman
  stub trivy
  export CLOUDSDK_CONFIG="$BATS_TEST_TMPDIR/gcloud"
}

@test "scripts pass shellcheck" {
  assert_shellcheck image_build image_scan image_push image_run image_test
}

@test "image_build builds the image with the version, revision and last commit's time" {
  tag_versions v1.2.3
  run image_build
  assert_success
  assert_equal "$(cat "$STUBS/podman.calls")" "build --source-date-epoch $(git log -1 --format=%ct) --build-arg REVISION=$(git rev-parse HEAD) \
--build-arg VERSION=1.2.3 --tag $IMAGE --file $DEVENV_ROOT/Containerfile $DEVENV_ROOT"
}

@test "image_build takes the version from VERSION" {
  VERSION=2.0.0 run image_build
  assert_success
  run grep -c -- "--build-arg VERSION=2.0.0 " "$STUBS/podman.calls"
  assert_output 1
}

@test "image_scan scans the saved image for fixable vulnerabilities and removes the archive" {
  # shellcheck disable=SC2016 # expanded by the stub
  stub podman '[ "$1" = save ] && touch "$5"'
  run image_scan
  assert_success
  local archive
  archive=$(sed -nE "s#^save --format docker-archive --output ([^ ]+) $IMAGE\$#\1#p" "$STUBS/podman.calls")
  assert [ -n "$archive" ]
  assert [ ! -e "$archive" ]
  assert_equal "$(cat "$STUBS/trivy.calls")" "image --skip-version-check --input $archive --ignore-unfixed --severity HIGH,CRITICAL --exit-code 1"
}

@test "image_scan writes a SARIF report of all fixable vulnerabilities" {
  run image_scan report.sarif
  assert_success
  run grep -c -- "^image --skip-version-check --input [^ ]* --ignore-unfixed --format sarif --output report.sarif$" "$STUBS/trivy.calls"
  assert_output 1
}

@test "image_scan disables Trivy's VEX notice" {
  unset TRIVY_DISABLE_VEX_NOTICE
  # shellcheck disable=SC2016 # expanded by the stub
  stub trivy 'echo "${TRIVY_DISABLE_VEX_NOTICE:-unset}" >>"$0.env"'
  run image_scan report.sarif
  assert_success
  assert_equal "$(cat "$STUBS/trivy.env")" $'true\ntrue'
}

@test "image_scan fails when trivy finds vulnerabilities" {
  stub trivy 'exit 1'
  run image_scan
  assert_failure
}

@test "image_push requires REGISTRY_IMAGE" {
  run image_push
  assert_failure
  assert_output --partial "REGISTRY_IMAGE must be set"
}

@test "image_push pushes the version, its major.minor, major and latest tags" {
  REGISTRY_IMAGE=registry.example.com/image VERSION=1.2.3 run image_push
  assert_success
  local tag expected=""
  for tag in 1.2.3 1.2 1 latest; do
    expected+="tag $IMAGE registry.example.com/image:$tag"$'\n'"push registry.example.com/image:$tag"$'\n'
  done
  assert_equal "$(cat "$STUBS/podman.calls")" "${expected%$'\n'}"
}

@test "image_run publishes the port and passes configured variables" {
  PORT=9090 run image_run --interactive
  assert_success
  assert_equal "$(cat "$STUBS/podman.calls")" "run --rm --publish 127.0.0.1:9090:9090 --env PORT=9090 --env DRY_RUN --interactive $IMAGE"
}

@test "image_run mounts Application Default Credentials readable by the image's user" {
  mkdir -p "$CLOUDSDK_CONFIG"
  touch "$CLOUDSDK_CONFIG/application_default_credentials.json"
  # shellcheck disable=SC2016 # expanded by the stub
  stub podman '[ "$1" = image ] && echo 1000 || true'
  run image_run
  assert_success
  assert_equal "$(tail -n 1 "$STUBS/podman.calls")" "run --rm --publish 127.0.0.1:8080:8080 --env PORT=8080 --env DRY_RUN --userns=keep-id:uid=1000,gid=1000 \
--volume $CLOUDSDK_CONFIG/application_default_credentials.json:/etc/gcloud/adc.json:ro --env GOOGLE_APPLICATION_CREDENTIALS=/etc/gcloud/adc.json $IMAGE"
}
