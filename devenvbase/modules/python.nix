{
  config,
  lib,
  ...
}:

let
  python = config.languages.python;
in
{
  # Baseline for projects enabling Python; requires the `nixpkgs-python` input in the project's devenv.yaml
  languages.python = lib.mkIf python.enable {
    version = lib.mkDefault "3.14.8";
    uv = {
      enable = lib.mkDefault true;
      sync.enable = lib.mkDefault true;
    };
  };
}
