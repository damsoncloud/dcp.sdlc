{
  config,
  pkgs,
  lib,
  ...
}:

{
  cachix.pull = [
    "cachix"
    "devenv"
    "nixpkgs-python"
    "nixpkgs-terraform"
  ];

  packages = [
    pkgs.pre-commit
  ];

  starship.enable = lib.mkIf (builtins.getEnv "CI" != "true") true;

  git-hooks.hooks = {
    actionlint.enable = true;
    check-json.enable = true;
    check-shebang-scripts-are-executable.enable = true;
    end-of-file-fixer = {
      enable = true;
      excludes = [ "devenv.lock" ];
    };
    hadolint.enable = true;
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
      settings.binPath = lib.mkIf config.languages.python.uv.enable "${config.env.UV_PROJECT_ENVIRONMENT}/bin/mypy";
      args = lib.mkIf config.languages.python.uv.enable [
        "--python-executable"
        "${config.env.UV_PROJECT_ENVIRONMENT}/bin/python"
      ];
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

  scripts = {
    gcloud_setup = {
      description = "Set up gcloud CLI";
      packages = [ pkgs.google-cloud-sdk ];
      exec = ''
        gcloud auth login $USER_EMAIL --no-launch-browser
        gcloud auth configure-docker europe-west4-docker.pkg.dev
        gcloud auth application-default login --no-launch-browser
      '';
    };
  };
}
