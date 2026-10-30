# Damson Cloud Platform SDLC

Shared software development lifecycle (SDLC) components for Damson Cloud repositories: a reusable devenv base, a GitHub Actions composite action initialising
it, and reusable GitHub Actions workflows for container images and for keeping repositories up to date with this one.

## Contents

* [`devenvbase/`](devenvbase/README.md) - reusable base for devenv configurations: git hooks, Python baseline, container image and versioning scripts.
* [`.github/actions/initialise_devenv/`](.github/actions/initialise_devenv/action.yml) - composite action installing Nix and devenv, running `devenv test` and
  optionally authenticating to Google Cloud.
* [`.github/workflows/`](.github/workflows/) - reusable workflows (`workflow_call`) and this repository's own CI and release workflows.

## Using dcp.sdlc in a repository

A repository pins every reference to this repository to the same release: the devenvbase input in `devenv.yaml` and all GitHub Actions references. The scripts
called by the reusable workflows come from devenvbase, so both must always move together.

```yaml
# devenv.yaml
inputs:
  devenvbase:
    url: github:damsoncloud/dcp.sdlc/v1.1.0?dir=devenvbase
    flake: false
```

```yaml
# .github/workflows/*.yaml
- uses: damsoncloud/dcp.sdlc/.github/actions/initialise_devenv@v1.1.0
```

New repositories get this set-up from the private [TEMPLATE](https://github.com/damsoncloud/TEMPLATE) repository.

### CI conventions

Each repository has a CI workflow in `.github/workflows/cicd.yaml`, triggered by pull requests and pushes to `main`. Its result is reported by a job named `ci`, the status
check required by the organisation's ruleset. Workflows calling reusable workflows add a `ci` job depending on them, as in the [example callers](#reusable-workflows),
because checks of reusable workflows are reported under the calling job's name.

### Upgrades

Do not upgrade the references by hand or with Dependabot, which can only update the GitHub Actions references. Instead, run `dcp_sdlc_upgrade_pr [version]` in
the repository's devenv shell: it creates a branch, upgrades to the release, the latest by default, updates all devenv inputs, runs `devenv test` and opens a pull
request. `dcp_sdlc_upgrade [version]` only updates the references and the devenvbase lock.

The scheduled [`dcp-sdlc-check.yaml`](.github/workflows/dcp-sdlc-check.yaml) workflow tells when to upgrade. It validates the upgrade to the latest release in the
runner and keeps one open GitHub issue, labelled `dcp.sdlc upgrade`, with the result and the command above; the issue is closed once the repository is up to date.
The upgrade itself cannot be automated with `GITHUB_TOKEN`, which cannot push commits changing workflow files.

Repositories with Dependabot ignore this repository:

```yaml
ignore:
  - dependency-name: damsoncloud/dcp.sdlc*
```

## Composite action

[`initialise_devenv`](.github/actions/initialise_devenv/action.yml) prepares a GitHub Actions runner: it checks out the repository, installs Nix and devenv, configures
the public Cachix caches and runs `devenv test`. Optionally it caches the Nix store and Podman images and authenticates to Google Cloud with Workload Identity
Federation. See the action's description and inputs for details.

Subsequent steps run commands in the devenv shell with `shell: devenv shell bash -- -e {0}`.

## Reusable workflows

The callers grant the listed permissions; reusable workflows cannot exceed them.

* [`container-image-ci.yaml`](.github/workflows/container-image-ci.yaml) builds, smoke-tests and scans the container image, uploading the scan to GitHub code
  scanning. Permissions: `contents: read`, `security-events: write`.
* [`container-image-release.yaml`](.github/workflows/container-image-release.yaml) bumps the version from the latest `v*` tag, builds, smoke-tests and scans the
  image, pushes it to GitHub Packages, creates a GitHub release and opens a version bump pull request. Runs on the default branch only. Input `bump`: `major`,
  `minor` or `patch`. Permissions: `contents: write`, `packages: write`, `pull-requests: write`.
* [`container-image-scan.yaml`](.github/workflows/container-image-scan.yaml) scans a published image for vulnerabilities, uploading the results to GitHub code
  scanning. Input `tag`, defaults to `latest`. Permissions: `contents: read`, `security-events: write`.
* [`dcp-sdlc-check.yaml`](.github/workflows/dcp-sdlc-check.yaml) checks for a newer dcp.sdlc release, validates the upgrade without pushing it and keeps an upgrade
  issue up to date; it fails when the upgrade does not pass validation. Permissions: `contents: read`, `issues: write`.
* [`dcp-sdlc-upgrade.yaml`](.github/workflows/dcp-sdlc-upgrade.yaml) is deprecated and will be removed in the next major release: it cannot push the workflow changes of
  an upgrade with `GITHUB_TOKEN`. Use `dcp-sdlc-check.yaml` instead.

The container image workflows require the devenvbase [`container-image` module](devenvbase/README.md#container-image-module). The release workflow opens its
version bump pull request with `GITHUB_TOKEN`, whose workflows run only once a maintainer approves them when reviewing.

Example callers:

```yaml
# .github/workflows/cicd.yaml
name: CI/CD pipeline

on:
  workflow_dispatch:
  pull_request:
  push:
    branches:
      - main

permissions:
  contents: read
  security-events: write

jobs:
  container-image:
    uses: damsoncloud/dcp.sdlc/.github/workflows/container-image-ci.yaml@v1.1.0

  ci:
    if: always()
    needs: container-image
    runs-on: ubuntu-latest
    steps:
      - run: test "${{ needs.container-image.result }}" = success
```

```yaml
# .github/workflows/release.yaml
name: Release

on:
  workflow_dispatch:
    inputs:
      bump:
        description: Part of the semantic version to increase
        type: choice
        options:
          - patch
          - minor
          - major
        default: patch

permissions:
  contents: read

jobs:
  release:
    permissions:
      contents: write
      packages: write
      pull-requests: write
    uses: damsoncloud/dcp.sdlc/.github/workflows/container-image-release.yaml@v1.1.0
    with:
      bump: ${{ inputs.bump }}
```

```yaml
# .github/workflows/scan.yaml
name: Vulnerability scan

on:
  schedule:
    - cron: '0 6 * * 1'
  workflow_dispatch:

permissions:
  contents: read
  security-events: write

jobs:
  scan:
    uses: damsoncloud/dcp.sdlc/.github/workflows/container-image-scan.yaml@v1.1.0
```

```yaml
# .github/workflows/dcp-sdlc-check.yaml
name: dcp.sdlc check

on:
  schedule:
    - cron: '0 5 * * 1'
  workflow_dispatch:

permissions:
  contents: read

jobs:
  check:
    permissions:
      contents: read
      issues: write
    uses: damsoncloud/dcp.sdlc/.github/workflows/dcp-sdlc-check.yaml@v1.1.0
```

## Releases

Releases follow [semantic versioning](https://semver.org/). The [`release.yaml`](.github/workflows/release.yaml) workflow, dispatched manually on `main` with the part
of the version to increase, tags `main` as `vX.Y.Z`, moves the floating major tag `vX` to it and creates a GitHub release.

The reusable workflows reference this repository's composite action by the floating major tag, e.g. `initialise_devenv@v1`, because `GITHUB_TOKEN` cannot push commits
changing workflow files. Before a major release, change these references to the new major in a pull request; the release refuses to proceed otherwise.

## Contributing

Use the devenv environment for building, testing and running code. It ensures use of tools specific to this particular project.

* `devenv shell` starts the shell.
* `devenv test` runs the git hooks.

This repository imports `./devenvbase` directly, so its shell and CI always use the working copy of devenvbase. Its
[`cicd.yaml`](.github/workflows/cicd.yaml) workflow runs `devenv test` with the working copy of the composite action.
