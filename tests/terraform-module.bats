#!/usr/bin/env bats

setup() {
  load test_helper
  common_setup
}

# Commit a module with an input, and a README.md with the given content, in the given directory
commit_module() {
  local dir=$1 readme=$2
  commit_files "$dir/main.tf" 'variable "name" {
  description = "Name of the thing."
  type        = string
}' "$dir/README.md" "$readme"
}

markers='# Module

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->

## Licence'

@test "terraform_docs passes shellcheck" {
  local script wrapper
  script=$(sed -nE 's#.* (/nix/store/[^ ]+-script) .*#\1#p' "$(command -v terraform_docs)")
  wrapper=$(grep -oE '/nix/store/[^ /]+-terraform-docs' "$script")
  run shellcheck "$wrapper"
  assert_success
}

@test "terraform is pinned to 1.15.9" {
  run terraform version
  assert_line --index 0 "Terraform v1.15.9"
}

@test "terraform_docs generates the inputs and outputs between the markers only" {
  commit_module . "$markers"
  run terraform_docs
  assert_success
  run cat README.md
  assert_line --index 0 "# Module"
  assert_line "## Inputs"
  assert_line "| name | Name of the thing. | \`string\` | n/a | yes |"
  assert_line "## Outputs"
  assert_line --index 2 "<!-- markdownlint-capture -->"
  assert_line --index 3 "<!-- markdownlint-disable MD013 -->"
  assert_line --index -3 "<!-- markdownlint-restore -->"
  refute_line "## Providers"
  refute_line --partial "<a name="
  assert_line --index -1 "## Licence"
}

@test "terraform_docs keeps the trailing newline when the markers end the README.md" {
  commit_module . "# Module

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->"
  run terraform_docs
  assert_success
  assert_equal "$(tail -c 1 README.md | od -An -c | tr -d ' ')" '\n'
}

@test "terraform_docs passes its arguments to terraform-docs" {
  commit_module . "$markers"
  run terraform_docs --output-check
  assert_failure
  run git status --porcelain
  assert_output ""
  run terraform_docs
  assert_success
  run terraform_docs --output-check
  assert_success
}

@test "terraform_docs documents the module in DEVENV_ROOT from any directory" {
  commit_module . "$markers"
  mkdir -p tests
  cd tests
  run terraform_docs
  assert_success
  run grep -c "| name | Name of the thing." "$DEVENV_ROOT/README.md"
  assert_output 1
}

@test "terraform_docs also documents the submodules" {
  commit_module . "$markers"
  commit_module modules/sub "$markers"
  run terraform_docs
  assert_success
  run grep -c "| name | Name of the thing." README.md modules/sub/README.md
  assert_output "README.md:1
modules/sub/README.md:1"
}

@test "terraform_docs ignores directories in modules/ without Terraform files" {
  commit_module . "$markers"
  mkdir -p modules/empty
  run terraform_docs
  assert_success
  assert [ ! -e modules/empty/README.md ]
}

@test "terraform_docs fails without the markers, without changing the README.md" {
  commit_module . "# Module"
  run terraform_docs
  assert_failure
  assert_output --partial "README.md: add the <!-- BEGIN_TF_DOCS --> and <!-- END_TF_DOCS --> markers"
  run git status --porcelain
  assert_output ""
}

@test "terraform_docs fails when a submodule has no README.md, without creating it" {
  commit_module . "$markers"
  commit_files modules/sub/main.tf 'variable "name" {
  type = string
}'
  run terraform_docs
  assert_failure
  assert_output --partial "modules/sub/README.md: add the"
  assert [ ! -e modules/sub/README.md ]
}
