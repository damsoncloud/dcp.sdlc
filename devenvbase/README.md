# Devenv base

Reusable base for [devenv](https://devenv.sh) configurations of Damson Cloud repositories: a single place to manage git hooks, language baselines and common scripts.

## Usage

Add the input and the import to the repository's `devenv.yaml`, pinned to a [dcp.sdlc release](../README.md#using-dcpsdlc-in-a-repository). Repositories enabling Python
also need the `nixpkgs-python` input.

```yaml
inputs:
  devenvbase:
    url: github:damsoncloud/dcp.sdlc/v1.1.0?dir=devenvbase
    flake: false
  nixpkgs-python:
    url: github:cachix/nixpkgs-python

imports:
  - devenvbase
```

Settings below are defaults: a repository's own `devenv.nix` can override them.

## What it provides

* Public Cachix binary caches: `cachix`, `devenv`, `nixpkgs-python` and `nixpkgs-terraform`.
* `pre-commit`, and outside CI also the `gcloud` CLI and the [starship](https://starship.rs) prompt.
* `.ruff.toml` generated from [`.ruff.toml`](.ruff.toml); it is not committed in repositories.
* Git hooks, run on commit and by `devenv test`:

  | Area | Hooks |
  | --- | --- |
  | General | `check-json`, `check-shebang-scripts-are-executable`, `end-of-file-fixer`, `keep-sorted`, `mixed-line-endings`, `pretty-format-json`, `trufflehog` |
  | Git | `no-commit-to-branch` (no commits on `main`) |
  | GitHub Actions | `actionlint` |
  | YAML and Markdown | `yamllint` (except workflows and actions), `markdownlint` (180 characters per line) |
  | Shell | `shellcheck` |
  | Containers | `hadolint` on `Dockerfile`, `Containerfile` and their variants, e.g. `app.Containerfile` |
  | Nix | `nixfmt` |
  | Python | `ruff`, `mypy` (the project's venv mypy with uv, so plugins such as `pydantic.mypy` apply) |
  | Terraform | `terraform-format`, `terraform-validate` |

* Scripts:

  | Script | Description |
  | --- | --- |
  | `gcloud_setup` | Logs in to the `gcloud` CLI and Application Default Credentials, outside CI only. |
  | `version_latest` | Prints the highest released version from `v*` tags, or `0.0.0` without any. |
  | `version_bump <major\|minor\|patch>` | Prints the latest released version bumped by the given part; uv projects also get it set in `pyproject.toml` and `uv.lock`. |
  | `dcp_sdlc_version` | Prints the dcp.sdlc release devenvbase is pinned to. |
  | `dcp_sdlc_latest` | Prints the latest dcp.sdlc release. |
  | `dcp_sdlc_upgrade [version]` | Pins GitHub Actions references and devenvbase to a dcp.sdlc release, the latest by default, and updates the devenvbase lock. |
  | `dcp_sdlc_upgrade_pr [version]` | Upgrades to a dcp.sdlc release, the latest by default, updates all devenv inputs, runs `devenv test` and opens a pull request. |

## Python baseline

When a repository enables Python with `languages.python.enable = true`, devenvbase also sets:

* Python version `3.14.8`, from the `nixpkgs-python` input,
* uv, with `uv sync` on shell entry,
* `devenv test` running the git hooks only after `uv sync` finished.

Python dependencies, including `mypy`, `pytest` and `pytest-cov` as development dependencies, belong to the project's `pyproject.toml`. Tests must reach at least 90% line
and branch coverage, configured in `pyproject.toml`, e.g.:

```toml
[tool.pytest]
addopts = ["--cov=<package>", "--cov-report=term-missing"]

[tool.coverage.run]
branch = true

[tool.coverage.report]
fail_under = 90
```

## Container image module

Opt-in scripts to build, test, scan, run and release a container image with [Podman](https://podman.io) and [Trivy](https://trivy.dev). They are also the interface used
by the [reusable container image workflows](../README.md#reusable-workflows).

```nix
dcp.containerImage = {
  enable = true;
  smokeTest = "function_test -t offline";
  run.passEnv = [ "DRY_RUN" ];
};
```

| Option | Default | Description |
| --- | --- | --- |
| `enable` | `false` | Enables the module. |
| `name` | `localhost/<repository directory>:local` | Local image reference, exported as `IMAGE`. Scripts use `$IMAGE`, so it can be overridden per command. |
| `containerfile` | `Containerfile` | Containerfile path relative to the repository root. |
| `buildArgs` | `{ }` | Additional build arguments; values are expanded by the shell. |
| `versionCommand` | `uv version --short` with uv, otherwise `version_latest` | Command printing the project version; the `VERSION` environment variable takes precedence. |
| `port` | `8080` | Port the container listens on; the `PORT` environment variable takes precedence. |
| `smokeTest` | `null` | Command run against the running container, with `PORT` exported. |
| `scanSeverity` | `HIGH,CRITICAL` | Severities of fixable vulnerabilities failing the scan. |
| `run.passEnv` | `[ ]` | Environment variables passed to the container by `image_run`, only when set. |

| Script | Description |
| --- | --- |
| `image_build` | Builds the image, created at the last commit's time, with `VERSION`, `REVISION` and, with Python and uv, `PYTHON_VERSION` and `UV_VERSION`. |
| `image_test` | Starts the container without credentials, waits for an HTTP response and runs `smokeTest`. Exists only when `smokeTest` is set. |
| `image_scan [sarif-file]` | Scans the image with Trivy, failing on fixable vulnerabilities of `scanSeverity`; optionally writes a SARIF report of all fixable ones. |
| `image_run [podman options]` | Runs the container locally, mounting Application Default Credentials read-only when present. |
| `image_push` | Pushes the image to `REGISTRY_IMAGE` tagged with the version, its `major.minor`, `major` and `latest`. |

A Containerfile using the build arguments declares them, e.g. `ARG PYTHON_VERSION` followed by `FROM docker.io/library/python:${PYTHON_VERSION}-slim`, so the image
uses the same Python and uv versions as the development environment.
