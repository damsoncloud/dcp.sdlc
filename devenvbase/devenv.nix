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
    check-json.enable = true;
    hadolint.enable = true;
    no-commit-to-branch.enable = true;
    nixfmt.enable = true;
    markdownlint.enable = true;
    keep-sorted.enable = true;
    pretty-format-json.enable = true;
    ruff.enable = true;
    shellcheck.enable = true;
    terraform-format.enable = true;
    terraform-validate.enable = true;
    trufflehog.enable = true;
    yamllint.enable = true;
  };
}
