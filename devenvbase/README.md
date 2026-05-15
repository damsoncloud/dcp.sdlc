# Devenv base

Reusable base for devenv configurations. Single place to manage tens of configs.

## Usage

### In another repo

To import the base devenv config in another repo/project add the following to the
project's `devenv.yaml` file:

```yaml
...
inputs:
  devenvbase:
    url: github:damsoncloud/dcp.sdlc?dir=devenvbase
    inputs:
      git-hooks:
        follows: git-hooks
      nixpkgs:
        follows: nixpkgs
    flake: false
...
imports:
  - ./devenvbase
...
```
