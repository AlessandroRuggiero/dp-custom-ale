# Hardened, Wayland-only VS Code container for Fedora + Podman.
#
# Design intent: isolate the Electron/Chromium process (and whatever
# extensions/npm/node tooling run inside it) from the host, using the
# container boundary as the sandbox instead of Chromium's own setuid
# sandbox (which can't init inside a rootless container anyway).
FROM fedora:44

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
        zsh \
        tar \
        gzip \
        xz \
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

# Starship prompt, via its official installer (not packaged in Fedora's main
# repos). Lands in /usr/local/bin; its config is ~/.config/starship.toml,
# which sits in the persisted config mount.
RUN curl -fsSL https://starship.rs/install.sh | sh -s -- -y

# The integrated terminal renders with fonts from inside the container, so
# starship's Nerd Font icons show as boxes unless one is installed here. Only
# the four Mono faces the terminal uses are kept — the full archive is ~100
# files at ~2.5MB each.
RUN mkdir -p /usr/local/share/fonts/JetBrainsMonoNerdFont && \
    curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz \
      | tar -xJ -C /usr/local/share/fonts/JetBrainsMonoNerdFont \
          JetBrainsMonoNerdFontMono-Regular.ttf \
          JetBrainsMonoNerdFontMono-Bold.ttf \
          JetBrainsMonoNerdFontMono-Italic.ttf \
          JetBrainsMonoNerdFontMono-BoldItalic.ttf && \
    fc-cache -f

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
    chmod -R a+rX /opt/vscode-extensions && \
    (echo "${VSCODE_EXTENSIONS}"; find /opt/vscode-extensions -type f | sort | wc -l) \
        > /opt/vscode-extensions/.bundle-id

# The workspace arrives as a bind mount whose owning UID need not match the
# penguin user inside the namespace. Git then refuses the repo with "detected
# dubious ownership", VS Code's SCM provider fails silently, and the explorer
# shows no M/U badges or colours. --system so it holds whatever UID the
# entrypoint remaps penguin to at runtime.
RUN git config --system --add safe.directory /workspace

COPY setup-penguin.sh /usr/local/bin/setup-penguin.sh
RUN /usr/local/bin/setup-penguin.sh

# setup-penguin.sh is shared and creates penguin with bash; only this image
# switches to zsh. The integrated terminal opens the user's login shell.
RUN usermod -s /bin/zsh penguin

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY code/code_entrypoint.sh /usr/local/bin/code_entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/code_entrypoint.sh

ENV HOME=/home/penguin
ENV ELECTRON_OZONE_PLATFORM_HINT=wayland
ENV NO_AT_BRIDGE=1
# $HOME itself is not persisted, so ~/.zshrc and history would vanish with the
# container. Keep zsh's dotfiles in the config mount instead.
ENV ZDOTDIR=/home/penguin/.config/zsh
# VS Code picks the terminal shell from $SHELL before the passwd entry, so
# pin it too rather than rely on nothing upstream setting it.
ENV SHELL=/bin/zsh

WORKDIR /workspace

# entrypoint.sh maps PUID/PGID onto the penguin user, then gosu-drops into
# code_entrypoint.sh, which enforces the Wayland-only gate before exec'ing
# the Electron binary.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh", "/usr/local/bin/code_entrypoint.sh"]
