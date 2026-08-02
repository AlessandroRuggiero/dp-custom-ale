#!/bin/bash
# Refuses to launch VS Code unless a real Wayland connection is present
# and no X11 display is offered — the "strictly Wayland" gate, enforced
# at runtime rather than left to Electron's auto-detection.
#
# Invoked by the shared entrypoint.sh, so it already runs as the penguin
# user with the host's UID/GID mapped in (HOME=/home/penguin).
set -euo pipefail

if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    echo "entrypoint: WAYLAND_DISPLAY is not set — refusing to start (no X11 fallback permitted)." >&2
    exit 1
fi

if [ ! -S "${XDG_RUNTIME_DIR:-/nonexistent}/${WAYLAND_DISPLAY}" ]; then
    echo "entrypoint: no Wayland socket at \${XDG_RUNTIME_DIR}/\${WAYLAND_DISPLAY} — refusing to start." >&2
    exit 1
fi

if [ -n "${DISPLAY:-}" ]; then
    echo "entrypoint: DISPLAY is set (${DISPLAY}) — this container is Wayland-only, unset DISPLAY on launch." >&2
    exit 1
fi

# VS Code creates its IPC socket (vscode-*-main.sock) in XDG_RUNTIME_DIR.
# That directory must be writable by this user or startup dies with
# "Error: listen EACCES" — the run script mounts a tmpfs there with
# matching uid/gid to satisfy it.
if [ ! -w "${XDG_RUNTIME_DIR}" ]; then
    echo "entrypoint: ${XDG_RUNTIME_DIR} is not writable by $(id -un) — VS Code cannot create its IPC socket." >&2
    exit 1
fi

DATA_DIR="${HOME}/.vscode-container/data"
EXTENSIONS_DIR="${HOME}/.vscode-container/extensions"
BUNDLED_EXTENSIONS=/opt/vscode-extensions

# Seeding. Both dirs above are persisted config mounts, so extensions baked
# into the image at build time have to be copied in here rather than shipped
# in place.
#
# The image stamps a bundle id next to its extensions; we re-seed whenever
# the copy in the mount doesn't carry the same one. That covers a fresh
# mount, a new image version, and — the reason this isn't just a first-run
# check — a copy that died halfway through and left a half-populated icons
# directory, which renders as blank squares in the explorer rather than as
# an obvious failure.
#
# Only the bundled extension directories are touched; anything the user
# installed themselves is left alone.
if [ -d "${BUNDLED_EXTENSIONS}" ] &&
   ! cmp -s "${BUNDLED_EXTENSIONS}/.bundle-id" "${EXTENSIONS_DIR}/.bundle-id"; then
    echo "entrypoint: seeding bundled extensions into ${EXTENSIONS_DIR}" >&2
    mkdir -p "${EXTENSIONS_DIR}"

    # Stage the whole copy first, then move each extension into place. A
    # rename is atomic, so an interrupted run can never leave a partial
    # extension behind, and .bundle-id lands only once every one is there.
    staging="${EXTENSIONS_DIR}/.seed.$$"
    rm -rf "${staging}"
    mkdir -p "${staging}"
    cp -R "${BUNDLED_EXTENSIONS}/." "${staging}/"

    for bundled in "${staging}"/*/; do
        name="$(basename "${bundled}")"
        rm -rf "${EXTENSIONS_DIR:?}/${name}"
        mv "${bundled}" "${EXTENSIONS_DIR}/${name}"
    done

    mv "${staging}/.bundle-id" "${EXTENSIONS_DIR}/.bundle-id"
    rm -rf "${staging}"
fi

# Likewise, activate the bundled icon theme only if the user has no
# settings.json at all; an existing one is left completely alone.
if [ ! -e "${DATA_DIR}/User/settings.json" ]; then
    mkdir -p "${DATA_DIR}/User"
    printf '{\n    "workbench.iconTheme": "material-icon-theme"\n}\n' \
        > "${DATA_DIR}/User/settings.json"
fi

# Exec the Electron binary directly, NOT the /usr/bin/code wrapper. That
# wrapper runs VS Code's CLI, which spawns the app detached and returns
# immediately — as PID 1 that exits the container and kills the app it
# just launched (symptom: the ozone warning prints, then a clean exit and
# no window). The binary below stays in the foreground.
exec /usr/share/code/code \
    --no-sandbox \
    --ozone-platform=wayland \
    --enable-features=UseOzonePlatform,WaylandWindowDecorations \
    --user-data-dir="${DATA_DIR}" \
    --extensions-dir="${EXTENSIONS_DIR}" \
    "${@:-/workspace}"
