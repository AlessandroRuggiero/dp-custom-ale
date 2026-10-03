#!/bin/bash
# Launches Claude Desktop under the same strictly-Wayland rules as the code
# image, after giving it a private session bus and keyring.
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

# The session bus socket goes in XDG_RUNTIME_DIR, which the run args mount
# as a tmpfs.
if [ ! -w "${XDG_RUNTIME_DIR}" ]; then
    echo "entrypoint: ${XDG_RUNTIME_DIR} is not writable by $(id -un) — cannot create the session bus." >&2
    exit 1
fi

# Keyring. Claude Desktop keeps its sign-in in Electron's safeStorage and
# treats Chromium's built-in "basic" key as no storage at all, so the
# --password-store=basic trick from the code image would mean signing in on
# every launch. Instead run a private dbus session with gnome-keyring on it.
# The host session bus is still not shared in.
#
# The login keyring is created and unlocked with an empty password, so on
# disk (~/.local/share/keyrings, a persisted mount) it is not encrypted. That
# is the same trade the code image makes, with a real keyring API on top.
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
dbus-daemon --session --fork --address="${DBUS_SESSION_BUS_ADDRESS}"
printf '' | gnome-keyring-daemon --daemonize --unlock --components=secrets > /dev/null

# Chromium's single-instance lock is a symlink named after hostname-pid. Every
# container gets a new hostname, so a lock left by a container that was
# killed rather than quit makes every later launch exit silently, believing
# the profile is in use on another machine. Clear it before starting. Cost:
# two containers launched at once would both run on the same profile.
rm -f "${HOME}/.config/Claude/Singleton"{Lock,Socket,Cookie}

# Exec the Electron binary, not a wrapper, so it stays in the foreground as
# PID 1 and gets podman's SIGTERM directly.
#
# --no-sandbox: Chromium's sandbox cannot initialise in a rootless container;
# the container is the sandbox.
# --password-store=gnome-libsecret: with no XDG_CURRENT_DESKTOP Chromium
# would not look for a keyring at all and fall back to basic.
exec /usr/lib/claude-desktop/claude-desktop \
    --no-sandbox \
    --password-store=gnome-libsecret \
    --ozone-platform=wayland \
    --enable-features=WaylandWindowDecorations \
    "$@"
