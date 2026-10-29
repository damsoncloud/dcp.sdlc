{
  config,
  pkgs,
  lib,
  ...
}:

let
  isCI = builtins.getEnv "CI" == "true";
in
{
  imports = [
    ./modules/container-image.nix
    ./modules/python.nix
    ./modules/sdlc.nix
    ./modules/versioning.nix
  ];

  cachix.pull = [
    "cachix"
    "devenv"
    "nixpkgs-python"
    "nixpkgs-terraform"
  ];

  packages = [
    pkgs.pre-commit
  ]
  ++ lib.optional (!isCI) pkgs.google-cloud-sdk;

  starship.enable = lib.mkIf (!isCI) true;

  git-hooks.hooks = {
    actionlint.enable = true;
    check-json.enable = true;
    check-shebang-scripts-are-executable.enable = true;
    end-of-file-fixer = {
      enable = true;
      excludes = [ "devenv.lock" ];
    };
    hadolint = {
      enable = true;
      # Priority between git-hooks' default (1000) and plain definitions (100), so projects can still override it
      files = lib.mkOverride 900 "(^|/)([^/]*\\.)?(Docker|Container)file(\\.[^/]*)?$";
    };
    nixfmt.enable = true;
    markdownlint = {
      enable = true;
      settings.configuration = {
        MD013 = {
          line_length = 180;
          heading_line_length = 180;
          code_block_line_length = 180;
        };
      };
    };
    mixed-line-endings.enable = true;
    mypy = {
      enable = true;
      require_serial = true;
      args = lib.mkIf config.languages.python.uv.enable [
        "--python-executable"
        "${config.env.UV_PROJECT_ENVIRONMENT}/bin/python"
      ];
      # mypy from the project's venv sees the project's plugins and stubs, e.g. pydantic.mypy
      settings.binPath = lib.mkIf config.languages.python.uv.enable (
        lib.mkDefault "${config.env.UV_PROJECT_ENVIRONMENT}/bin/mypy"
      );
    };
    no-commit-to-branch = {
      enable = true;
      stages = [ "commit-msg" ];
    };
    keep-sorted.enable = true;
    pretty-format-json.enable = true;
    ruff.enable = true;
    shellcheck.enable = true;
    terraform-format.enable = true;
    terraform-validate.enable = true;
    trufflehog.enable = true;
    yamllint = {
      enable = true;
      excludes = [
        "\.github/workflows/.*"
        "\.github/actions/.*"
      ];
    };
  };

  files.".ruff.toml".source = ./.ruff.toml;

  tasks."devenv:git-hooks:run".after = lib.mkIf config.languages.python.uv.sync.enable [
    "devenv:python:uv"
  ];

  scripts = {
    gcloud_setup = lib.mkIf (!isCI) {
      description = "Set up gcloud CLI";
      exec = ''
        gcloud auth login $USER_EMAIL --no-launch-browser
        gcloud auth configure-docker europe-west4-docker.pkg.dev
        gcloud auth application-default login --no-launch-browser
      '';
    };
  };
}
