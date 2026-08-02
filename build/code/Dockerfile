# Hardened, Wayland-only VS Code container for Fedora + Podman.
#
# Design intent: isolate the Electron/Chromium process (and whatever
# extensions/npm/node tooling run inside it) from the host, using the
# container boundary as the sandbox instead of Chromium's own setuid
# sandbox (which can't init inside a rootless container anyway).
FROM fedora:43

# Microsoft's VS Code repo + the runtime libs Electron needs to talk to
# a Wayland compositor. No X11 libs on purpose — if Ozone tried to fall
# back to X11 it would fail to find what it needs.
#
# mesa-libEGL / mesa-libGL / libglvnd-* are required: without libEGL.so.1
# Chromium's GPU process dies at startup with
#   "ANGLE Display::initialize error 12289: Could not dlopen native EGL"
# and takes the whole app down with it.
RUN rpm --import https://packages.microsoft.com/keys/microsoft.asc && \
    printf '[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\n' \
      > /etc/yum.repos.d/vscode.repo && \
    dnf install -y --setopt=install_weak_deps=False \
        code \
        git \
        mesa-dri-drivers \
        mesa-libgbm \
        mesa-libEGL \
        mesa-libGL \
        libglvnd-egl \
        libglvnd-glx \
        libxkbcommon \
        wayland-devel \
        libdrm \
        nss \
        at-spi2-core \
        dbus-libs \
        cairo \
        pango \
        alsa-lib \
        xdg-utils \
        fontconfig \
        google-noto-sans-fonts \
        google-noto-sans-mono-fonts \
        dejavu-sans-mono-fonts \
        liberation-mono-fonts && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# Extensions baked into the image. They deliberately do NOT go into
# $HOME/.vscode-container/extensions: that path is a persisted config
# mount at runtime, so the host mount would shadow anything installed
# here. code_entrypoint.sh seeds them into the mounted dir on first run.
ARG VSCODE_EXTENSIONS="PKief.material-icon-theme"
RUN for ext in ${VSCODE_EXTENSIONS}; do \
        code --no-sandbox \
            --user-data-dir=/tmp/vscode-build \
            --extensions-dir=/opt/vscode-extensions \
            --install-extension "$ext"; \
    done && \
    rm -rf /tmp/vscode-build && \
    chmod -R a+rX /opt/vscode-extensions

COPY setup-penguin.sh /usr/local/bin/setup-penguin.sh
RUN /usr/local/bin/setup-penguin.sh

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY code/code_entrypoint.sh /usr/local/bin/code_entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/code_entrypoint.sh

ENV HOME=/home/penguin
ENV ELECTRON_OZONE_PLATFORM_HINT=wayland
ENV NO_AT_BRIDGE=1

WORKDIR /workspace

# entrypoint.sh maps PUID/PGID onto the penguin user, then gosu-drops into
# code_entrypoint.sh, which enforces the Wayland-only gate before exec'ing
# the Electron binary.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh", "/usr/local/bin/code_entrypoint.sh"]
