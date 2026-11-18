#!/usr/bin/env bash
# Writes a Podman storage configuration override with the rootless default locations to the given path. Exits 2 without writing when not needed:
# not on Linux, as root, or when CONTAINERS_STORAGE_CONF, CONTAINERS_STORAGE_CONF_OVERRIDE or a user-level storage.conf already configures the storage.
# Podman 6 applies all fields of the system storage.conf to rootless users too, e.g. the rootful graphroot of Ubuntu's
# /usr/share/containers/storage.conf (https://bugzilla.redhat.com/show_bug.cgi?id=2537131).
set -euo pipefail

target=${1:?usage: container_storage_conf.sh <path>}
uid=$(id -u)

if [ "$(uname -s)" != Linux ] || [ "$uid" = 0 ] || [ -n "${CONTAINERS_STORAGE_CONF:-}" ] || [ -n "${CONTAINERS_STORAGE_CONF_OVERRIDE:-}" ] ||
  [ -e "${XDG_CONFIG_HOME:-$HOME/.config}/containers/storage.conf" ]; then
  exit 2
fi

data=${XDG_DATA_HOME:-$HOME/.local/share}
runtime=${XDG_RUNTIME_DIR:-}

# Same fallback as Podman's GetRuntimeDir(), without creating /run/user/<uid>
if [ -z "$runtime" ]; then
  tmp=${TMPDIR:-/tmp}
  runtime=${tmp%/}/storage-run-$uid
  candidate=/run/user/$uid
  if [ -d "$candidate" ] && [ -O "$candidate" ] && (((8#$(stat -c %a "$candidate") & 8#722) == 8#700)); then
    runtime=$candidate
  fi
fi

mkdir -p "$(dirname "$target")"
cat >"$target" <<CONF
[storage]
graphroot = "${data%/}/containers/storage"
runroot = "${runtime%/}/containers"
CONF
