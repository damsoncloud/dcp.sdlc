# Common set-up for testing devenv scripts: each test runs in its own git repository, exported as DEVENV_ROOT, with isolated git configuration

bats_load_library bats-support
bats_load_library bats-assert

common_setup() {
  export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/gitconfig" GIT_CONFIG_NOSYSTEM=1
  git config --global user.name Test
  git config --global user.email test@example.com
  git config --global init.defaultBranch main
  git config --global advice.detachedHead false

  STUBS="$BATS_TEST_TMPDIR/stubs"
  mkdir -p "$STUBS"
  PATH="$STUBS:$PATH"

  export DEVENV_ROOT="$BATS_TEST_TMPDIR/repository"
  git init --quiet "$DEVENV_ROOT"
  cd "$DEVENV_ROOT" || return
  git commit --quiet --allow-empty --message initial
}

# Replace a command with a script recording its arguments in $STUBS/<command>.calls, one call per line, and running the optional body
stub() {
  local name=$1 body=${2:-}
  printf '#!/usr/bin/env bash\necho "$*" >>"%s"\n%s\n' "$STUBS/$name.calls" "$body" >"$STUBS/$name"
  chmod +x "$STUBS/$name"
  touch "$STUBS/$name.calls"
}

# Add the files given as <path> <content> pairs to the repository and commit them
commit_files() {
  while (($#)); do
    mkdir -p "$(dirname "$1")"
    printf '%s\n' "$2" >"$1"
    git add "$1"
    shift 2
  done
  git commit --quiet --message files
}

# Create an annotated tag for each version on a new commit
tag_versions() {
  for version; do
    git commit --quiet --allow-empty --message "$version"
    git tag --annotate "$version" --message "$version"
  done
}

# Run shellcheck on the bodies of the given devenv scripts
assert_shellcheck() {
  local script
  for script; do
    run shellcheck --shell=bash "$(sed -nE 's#.* (/nix/store/[^ ]+-script) .*#\1#p' "$(command -v "$script")")"
    assert_success
  done
}
