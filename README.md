# Damson Cloud Platform SDLC stuff

This repository contains all the stuff related to DCP's SDLC setup, including common
components used during CI/CD on GitHub Actions, common setup pieces for devenv, etc.

## Contributing

Use `devenv` environment for building, testing, executing, running code. It ensures
use of tools specific to this particular project.

### Start shell

To start devenv shell, use `devenv shell` command.

### Use of git

After starting `devenv shell`, use its command-line `git` command to ensure pre-commit
hooks are applied (crucial for `git commit`). You can also figure out how to integrate
devenv with your IDE of choice.
