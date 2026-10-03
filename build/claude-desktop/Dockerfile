# Wayland-only Claude Desktop container, built the same way as the `code`
# image: the container boundary is the sandbox, only the compositor socket is
# shared in.
#
# Debian rather than Fedora: Anthropic publishes the Linux app (beta) only as
# a .deb for Ubuntu 22.04+ / Debian 12+, from its own apt repository.
FROM debian:13-slim

# Official install steps (code.claude.com/docs/en/desktop-linux): fetch the
# signing key, check its fingerprint, register the repo, apt install.
#
# --no-install-recommends drops QEMU/OVMF/virtiofsd (Cowork's VM, which needs
# /dev/kvm and /dev/vhost-vsock and is not wired up here) but also some things
# we do want, so those are listed explicitly:
#   ca-certificates  - TLS to claude.ai
#   libasound2t64    - Electron dlopens libasound at startup even with no audio
#   gnome-keyring    - the app saves its sign-in through libsecret; see
#                      claude_desktop_entrypoint.sh
#   dbus             - session bus for gnome-keyring to sit on
# mesa/EGL are what Chromium's GPU process needs to come up on /dev/dri, same
# as in the code image.
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl gpg && \
    curl -fsSLo /usr/share/keyrings/claude-desktop-archive-keyring.asc \
        https://downloads.claude.ai/claude-desktop/key.asc && \
    gpg --show-keys --with-colons /usr/share/keyrings/claude-desktop-archive-keyring.asc \
        | grep -q '^fpr:.*:31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE:$' && \
    echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main" \
        > /etc/apt/sources.list.d/claude-desktop.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        claude-desktop \
        libasound2t64 \
        gnome-keyring \
        dbus \
        git \
        libegl1 \
        libgl1 \
        libgl1-mesa-dri \
        fonts-dejavu-core \
        fonts-noto-color-emoji && \
    rm -rf /var/lib/apt/lists/*

# Same reason as in the code image: the bind-mounted workspace is owned by a
# UID git does not expect, and the Code tab's diff view goes blank.
RUN git config --system --add safe.directory /workspace

COPY setup-penguin.sh /usr/local/bin/setup-penguin.sh
RUN /usr/local/bin/setup-penguin.sh

# Configmount targets, created here so the bind mounts are not root-owned.
# ~/.config/Claude is the Electron profile, ~/.local/share/keyrings holds the
# saved sign-in, ~/.claude is what the Code tab's sessions use.
RUN mkdir -p /home/penguin/.config /home/penguin/.cache /home/penguin/.local/share \
             /home/penguin/.claude && \
    chown -R penguin:penguin /home/penguin

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY claude-desktop/claude_desktop_entrypoint.sh /usr/local/bin/claude_desktop_entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/claude_desktop_entrypoint.sh

ENV HOME=/home/penguin
ENV NO_AT_BRIDGE=1

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh", "/usr/local/bin/claude_desktop_entrypoint.sh"]
