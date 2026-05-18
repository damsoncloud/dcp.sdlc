{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  packages = [
    pkgs.pre-commit
    pkgs.starship
  ];

  enterShell = ''
    eval "$(starship init bash)"
  '';

  git-hooks.hooks = {
    actionlint.enable = true;
    check-json.enable = true;
    check-shebang-scripts-are-executable.enable = true;
    end-of-file-fixer.enable = true;
    hadolint.enable = true;
    nixfmt.enable = true;
    markdownlint.enable = true;
    mixed-line-endings.enable = true;
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
      excludes = [ "\.github/workflows/.*" ];
    };
  };
}
