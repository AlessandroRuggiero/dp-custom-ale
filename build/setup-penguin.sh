#!/bin/sh
set -e

# Install gosu (entrypoint.sh uses it to drop privileges) plus the shadow
# tools the entrypoint needs at runtime to remap the penguin UID/GID.
if command -v apt-get > /dev/null 2>&1; then
    apt-get update
    apt-get install -y gosu
    rm -rf /var/lib/apt/lists/*
elif command -v dnf > /dev/null 2>&1; then
    dnf install -y --setopt=install_weak_deps=False gosu shadow-utils
    dnf clean all
    rm -rf /var/cache/dnf
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
