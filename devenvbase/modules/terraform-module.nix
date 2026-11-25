{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dcp.terraformModule;
  docsDescription = "Generate the inputs and outputs of the module and its submodules in their README.md";

  # Shared by the git hook and the script, so both generate the same documentation
  terraformDocs = pkgs.writeShellScript "terraform-docs" ''
    set -euo pipefail
    shopt -s nullglob

    # Like enterTest, the module is in the devenv root; git hooks run outside the shell fall back to it as evaluated
    root="''${DEVENV_ROOT:-${config.devenv.root}}"

    # Generated table rows cannot be wrapped, so only they are excluded from the line length check. Restoring rather than enabling the rule keeps
    # its previous state, e.g. disabled in an editor's configuration.
    template=$'<!-- BEGIN_TF_DOCS -->\n<!-- markdownlint-capture -->\n<!-- markdownlint-disable MD013 -->\n{{ .Content }}\n<!-- markdownlint-restore -->\n<!-- END_TF_DOCS -->'
    args=(markdown table --output-file README.md --output-mode inject --anchor=false --html=false --show "inputs,outputs" --output-template "$template")
    readmes=("$root/README.md")
    # --recursive fails when the module has no submodules
    if [ -d "$root/modules" ]; then
      args+=(--recursive)
      for dir in "$root"/modules/*/; do
        tf_files=("$dir"*.tf)
        if [ "''${#tf_files[@]}" -gt 0 ]; then
          readmes+=("''${dir}README.md")
        fi
      done
    fi

    # terraform-docs creates a missing README.md, which pre-commit does not detect as untracked, and appends the tables to one without markers
    missing=0
    for readme in "''${readmes[@]}"; do
      if ! grep -q '^<!-- BEGIN_TF_DOCS -->$' "$readme" 2>/dev/null || ! grep -q '^<!-- END_TF_DOCS -->$' "$readme"; then
        echo "''${readme#"$root"/}: add the <!-- BEGIN_TF_DOCS --> and <!-- END_TF_DOCS --> markers where the inputs and outputs belong" >&2
        missing=1
      fi
    done
    if [ "$missing" -ne 0 ]; then
      exit 1
    fi

    ${lib.getExe pkgs.terraform-docs} "''${args[@]}" "$@" "$root"
  '';

  # A module calling providers through aliases, declared with `configuration_aliases`, cannot be validated on its own, as only its callers configure them;
  # a temporary file in its directory configures them empty while it is validated
  terraformValidate = pkgs.writeShellScript "terraform-validate" ''
    set -euo pipefail

    terraform=${lib.getExe config.git-hooks.hooks.terraform-validate.package}

    # Make sure temporary file is removed also when the validation fails
    aliases_file=""
    trap 'if [ -n "$aliases_file" ]; then rm -f "$aliases_file"; fi' EXIT

    mapfile -t dirs < <(for file in "$@"; do dirname "$file"; done | sort -u)
    for dir in "''${dirs[@]}"; do
      aliases=$(cat "$dir"/*.tf 2>/dev/null | tr '\n' ' ' | grep -oE 'configuration_aliases[[:space:]]*=[[:space:]]*\[[^]]*\]' |
        grep -oE '[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+' | sort -u || true)
      if [ -n "$aliases" ]; then
        aliases_file="$dir/zz_validate_provider_aliases.tf"
        for alias in $aliases; do
          printf 'provider "%s" {\n  alias = "%s"\n}\n\n' "''${alias%%.*}" "''${alias#*.}"
        done >"$aliases_file"
      fi
      "$terraform" -chdir="$dir" init -backend=false -input=false
      "$terraform" -chdir="$dir" validate
      if [ -n "$aliases_file" ]; then
        rm -f "$aliases_file"
        aliases_file=""
      fi
    done
  '';
in
{
  options.dcp.terraformModule = {
    enable = lib.mkEnableOption "the Terraform version, documentation and tests of a reusable Terraform module";

    docs.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether the `terraform-docs` git hook keeps the inputs and outputs in the README.md files up to date; the `terraform_docs` script is always available.";
    };

    test.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether `devenv test` runs `terraform test` of the root module.";
    };
  };

  # Requires the `nixpkgs-terraform` input in the module repository's devenv.yaml
  config = lib.mkIf cfg.enable {
    languages.terraform = {
      enable = true;
      version = lib.mkDefault "1.15.9";
    };

    git-hooks.hooks.terraform-docs = {
      enable = cfg.docs.enable;
      description = docsDescription;
      entry = "${terraformDocs}";
      files = "(\\.tf|README\\.md)$";
      pass_filenames = false;
    };

    git-hooks.hooks.terraform-validate.entry = lib.mkForce "${terraformValidate}";

    scripts.terraform_validate = {
      description = "Validate the Terraform configurations of the directories of the given files, configuring the provider aliases of modules for them";
      exec = "${terraformValidate} \"$@\"";
    };

    scripts.terraform_docs = {
      description = "${docsDescription}; arguments are passed to terraform-docs, e.g. --output-check";
      exec = "${terraformDocs} \"$@\"";
    };

    enterTest = lib.mkIf cfg.test.enable ''
      terraform -chdir="$DEVENV_ROOT" init -backend=false -input=false -upgrade
      terraform -chdir="$DEVENV_ROOT" test
    '';
  };
}
