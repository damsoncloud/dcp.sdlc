# Devenv base

Reusable base for devenv configurations. Single place to manage tens of configs.

## Usage

### In another repo

Make sure to NOT skip optional step from official [devenv setup guide](https://devenv.sh/getting-started/#3-configure-a-github-access-token-optional).
Your Personal Access Token must have repo read access set.

To import the base devenv config in another repo/project add the following to the
project's `devenv.yaml` file:

```yaml
...
inputs:
  devenvbase:
    url: github:damsoncloud/dcp.sdlc?dir=devenvbase
    flake: false
...
imports:
  - devenvbase
...
```
