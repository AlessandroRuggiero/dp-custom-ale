#!/bin/sh
set -e

# Install gosu (entrypoint.sh uses it to drop privileges) plus the shadow
# tools the entrypoint needs at runtime to remap the penguin UID/GID.
if command -v apt-get > /dev/null 2>&1; then
    apt-get update
    apt-get install -y gosu
    rm -rf /var/lib/apt/lists/*
elif command -v dnf > /dev/null 2>&1; then
    # Fedora ships no gosu package, so stand up a gosu-compatible shim over
    # setpriv (util-linux-core) instead. entrypoint.sh is shared with the
    # Debian images and calls `gosu penguin "$@"` unconditionally, so the
    # interface has to exist under that name.
    dnf install -y --setopt=install_weak_deps=False util-linux-core shadow-utils
    dnf clean all
    rm -rf /var/cache/dnf

    cat > /usr/local/bin/gosu <<'GOSU_SHIM'
#!/bin/sh
# gosu(1) subset: gosu user[:group] command [args...]
# setpriv execs in place rather than forking, matching gosu's signal and
# exit-code behaviour for a PID 1 entrypoint.
set -e

spec="$1"
shift

user="${spec%%:*}"
group="${spec#*:}"
if [ "$group" = "$spec" ]; then
    group="$user"
fi

# Real gosu sets HOME from the target user's passwd entry; nothing else here
# does, and VS Code resolves its data dirs from it.
HOME="$(getent passwd "$user" | cut -d: -f6)"
export HOME

exec setpriv --reuid "$user" --regid "$group" --init-groups -- "$@"
GOSU_SHIM
    chmod +x /usr/local/bin/gosu
else
    echo "setup-penguin: no supported package manager (apt-get or dnf) found" >&2
    exit 1
fi

OLD_USER="$1"

if [ -n "$OLD_USER" ] && getent passwd "$OLD_USER" > /dev/null 2>&1; then
    groupmod -n penguin "$OLD_USER"
    usermod -l penguin -d /home/penguin -m "$OLD_USER"
else
    groupadd -r penguin
    useradd -r -m -g penguin -s /bin/bash penguin
fi
