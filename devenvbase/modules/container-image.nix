{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dcp.containerImage;
  python = config.languages.python;
  port = "\${PORT:-${toString cfg.port}}";
  version = "\${VERSION:-$(${cfg.versionCommand})}";

  buildArgs = {
    VERSION = version;
    REVISION = "$(git -C \"$DEVENV_ROOT\" rev-parse HEAD)";
  }
  // lib.optionalAttrs (python.enable && python.version != null) { PYTHON_VERSION = python.version; }
  // lib.optionalAttrs python.uv.enable { UV_VERSION = python.uv.package.version; }
  // cfg.buildArgs;
in
{
  options.dcp.containerImage = with lib; {
    enable = mkEnableOption "scripts to build, test, scan, run and release a container image";

    name = mkOption {
      type = types.str;
      default = "localhost/${toLower (baseNameOf config.devenv.root)}:local";
      defaultText = literalExpression ''"localhost/<repository directory>:local"'';
      description = "Local image reference, exported as `IMAGE`; scripts operate on `$IMAGE`, so it can be overridden per command.";
    };

    containerfile = mkOption {
      type = types.str;
      default = "Containerfile";
      description = "Containerfile path relative to the repository root.";
    };

    buildArgs = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = ''
        Additional build arguments; values are expanded by the shell. `VERSION` and `REVISION` are always passed,
        `PYTHON_VERSION` and `UV_VERSION` when Python and uv are enabled.
      '';
    };

    versionCommand = mkOption {
      type = types.str;
      default = if python.uv.enable then "uv version --short" else "version_latest";
      defaultText = literalExpression ''"uv version --short" with uv, otherwise "version_latest"'';
      description = "Command printing the project version; the `VERSION` environment variable takes precedence.";
    };

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Default port the container listens on; the `PORT` environment variable takes precedence.";
    };

    smokeTest = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "function_test -t offline";
      description = "Command run by `image_test` against the running container, with `PORT` exported; `image_test` exists only when set.";
    };

    scanSeverity = mkOption {
      type = types.str;
      default = "HIGH,CRITICAL";
      description = "Severities of fixable vulnerabilities which fail `image_scan`.";
    };

    run.passEnv = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "DRY_RUN" ];
      description = "Environment variables passed to the container by `image_run`, only when set.";
    };
  };

  config = lib.mkIf cfg.enable {
    env.IMAGE = cfg.name;

    packages = [
      # keep-sorted start
      pkgs.podman
      pkgs.trivy
      # keep-sorted end
    ];

    scripts = {
      image_build = {
        description = "Build the container image";
        exec = ''
          set -euo pipefail
          podman build \
            --source-date-epoch "$(git -C "$DEVENV_ROOT" log -1 --format=%ct)" \
            ${
              lib.concatStringsSep " \\\n  " (lib.mapAttrsToList (n: v: "--build-arg ${n}=\"${v}\"") buildArgs)
            } \
            --tag "$IMAGE" \
            --file "$DEVENV_ROOT/${cfg.containerfile}" \
            "$DEVENV_ROOT"
        '';
      };

      image_scan = {
        description = "Scan the container image for vulnerabilities, failing on fixable ${cfg.scanSeverity} ones; optionally write a SARIF report: [sarif-file]";
        exec = ''
          set -euo pipefail
          archive=$(mktemp --suffix=.tar)
          trap 'rm -f "$archive"' EXIT
          podman save --format docker-archive --output "$archive" "$IMAGE"
          if [ -n "''${1:-}" ]; then
            trivy image --input "$archive" --ignore-unfixed --format sarif --output "$1"
          fi
          trivy image --input "$archive" --ignore-unfixed --severity ${cfg.scanSeverity} --exit-code 1
        '';
      };

      image_push = {
        description = "Push the container image to REGISTRY_IMAGE tagged with the project version, its major.minor, major and latest";
        exec = ''
          set -euo pipefail
          : "''${REGISTRY_IMAGE:?REGISTRY_IMAGE must be set}"
          version="${version}"
          IFS=. read -r major minor _ <<<"$version"
          for tag in "$version" "$major.$minor" "$major" latest; do
            podman tag "$IMAGE" "$REGISTRY_IMAGE:$tag"
            podman push "$REGISTRY_IMAGE:$tag"
          done
        '';
      };

      image_run = {
        description = "Run the container image locally, with Application Default Credentials mounted if present; extra arguments are passed to podman run";
        exec = ''
          set -euo pipefail
          port="${port}"
          adc="''${CLOUDSDK_CONFIG:-$HOME/.config/gcloud}/application_default_credentials.json"
          container_adc=/etc/gcloud/adc.json
          run_args=(${lib.concatMapStringsSep " " (name: "--env ${name}") cfg.run.passEnv})
          if [ -f "$adc" ]; then
            # keep-id maps the host user to the image's user, so the credentials file stays readable
            uid=$(podman image inspect --format '{{.Config.User}}' "$IMAGE")
            run_args+=(
              --userns="keep-id:uid=$uid,gid=$uid"
              --volume "$adc:$container_adc:ro"
              --env GOOGLE_APPLICATION_CREDENTIALS="$container_adc"
            )
          fi
          exec podman run --rm --publish "127.0.0.1:$port:$port" --env PORT="$port" "''${run_args[@]}" "$@" "$IMAGE"
        '';
      };

      image_test = lib.mkIf (cfg.smokeTest != null) {
        description = "Run smoke tests against the container image, without credentials";
        packages = [ pkgs.curl ];
        exec = ''
          set -euo pipefail
          export PORT="${port}"
          container=$(podman run --detach --rm --publish "127.0.0.1:$PORT:$PORT" --env PORT "$IMAGE")
          trap 'podman stop "$container" >/dev/null' EXIT
          # The port is published before the application listens, so wait for an HTTP response rather than a TCP connection
          for _ in $(seq 1 30); do
            curl --silent --output /dev/null "http://127.0.0.1:$PORT" && break
            sleep 1
          done
          ${cfg.smokeTest} "$@"
        '';
      };
    };
  };
}
