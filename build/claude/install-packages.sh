#!/bin/sh
# Extra packages for the Claude image (Fedora only).
set -eu

dnf install -y --setopt=install_weak_deps=False \
    poppler-utils \
    ripgrep \
    jq \
    diffutils

dnf clean all
rm -rf /var/cache/dnf /var/cache/libdnf5
