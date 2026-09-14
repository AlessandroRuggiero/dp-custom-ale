# Claude Code CLI on a Fedora base.
#
# There is no Fedora equivalent of a node:26-slim base tag pinning the runtime
# for us, so the Node version is a deliberate choice here — see the dnf line
# below.
FROM fedora:44

# Claude Code checks for updates on startup and rewrites its own install; both
# are pointless in an immutable image and just add latency to every run.
ENV NO_UPDATE_NOTIFIER=1
ENV DISABLE_AUTOUPDATER=1

# shadow-utils matters: entrypoint.sh calls groupmod/usermod at runtime and
# the fedora base ships neither. setup-penguin.sh installs it too, but this
# layer runs first and a missing usermod would only surface at container start.
#
# nodejs-npm rather than the bare `npm` provide: Fedora 43 ships both
# nodejs-npm (npm 10.x, for nodejs 22.x) and nodejs24-npm (npm 11.x), and both
# carry Provides: npm, so the unqualified name is ambiguous. Naming the
# subpackage pins npm to the same stream as the nodejs package above it.
RUN dnf install -y --setopt=install_weak_deps=False \
        git \
        less \
        shadow-utils \
        nodejs \
        nodejs-npm && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# No argument: unlike the node:26-slim base there is no pre-existing `node`
# user to rename, so the script takes its else branch and creates penguin
# fresh. The script is distro-aware — on Fedora it also stands up the
# setpriv-backed gosu shim that entrypoint.sh depends on, since Fedora
# packages no gosu.
COPY setup-penguin.sh /usr/local/bin/setup-penguin.sh
RUN /usr/local/bin/setup-penguin.sh

# Created here rather than left to the runtime: these are configmount targets,
# and a bind mount onto a missing path would otherwise be created root-owned.
RUN mkdir -p /home/penguin/.claude /home/penguin/.config /home/penguin/.cache && \
    chown -R penguin:penguin /home/penguin

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# The version is read out of package.json rather than written here so that
# dependabot can bump it like any other npm dependency.
COPY install-npm-global-from-package-json.sh /usr/local/bin/install-npm-global-from-package-json.sh
COPY claude/package.json /tmp/deps/package.json
RUN sh /usr/local/bin/install-npm-global-from-package-json.sh @anthropic-ai/claude-code /tmp/deps --cleanup

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh", "claude"]
