#!/usr/bin/env bash
#
# Is the published `code` image stale?
#
# Nothing else in this repo can answer that. Dependabot watches the
# Dockerfile, but neither of the two things that actually move inside this
# image shows up there:
#
#   * VS Code arrives via `dnf install code` from Microsoft's yum repo, so a
#     new editor release never changes a tracked file.
#   * Fedora rebuilds the `fedora:43` tag in place for CVE fixes, so the
#     runtime libs Electron links against move without the tag moving.
#
# So this compares both against the labels on the currently published image
# and prints a verdict. It needs dnf, so CI runs it inside a Fedora
# container. Locally:
#
#   podman run --rm -v "$PWD:/src:ro" \
#     -e IMAGE=ghcr.io/alessandroruggiero/dp-custom-ale/code \
#     fedora:43 /src/.github/scripts/check-upstream-code.sh
#
# It lives here rather than in build/code/ because it is CI tooling, not
# image content — nothing COPYs it in, and keeping it out of build/code/**
# means editing it doesn't trip the paths filter into a pointless rebuild.
#
# Everything human-readable goes to stderr; stdout carries only `key=value`
# lines, so CI can append it straight to $GITHUB_OUTPUT.

set -euo pipefail

log() { printf '%s\n' "$*" >&2; }

: "${IMAGE:?IMAGE must be set (e.g. ghcr.io/owner/repo/code)}"
TAG="${TAG:-main}"
DOCKERFILE="${DOCKERFILE:-/src/build/code/Dockerfile}"

for tool in skopeo jq; do
    command -v "$tool" >/dev/null && continue
    log "Installing $tool"
    dnf install -y -q --setopt=install_weak_deps=False "$tool" >&2
done

# --- Upstream VS Code -------------------------------------------------------
rpm --import https://packages.microsoft.com/keys/microsoft.asc
upstream=$(dnf -q \
    --repofrompath=vscode,https://packages.microsoft.com/yumrepos/vscode \
    --repo=vscode \
    repoquery --queryformat '%{version}-%{release}\n' code \
    | sort -V | tail -1)
if [ -z "$upstream" ]; then
    log "repoquery returned nothing for 'code'. Failing loudly: a silent"
    log "empty answer here reads as 'up to date' and freezes the editor."
    exit 1
fi
log "Upstream VS Code: $upstream"

# --- Base image -------------------------------------------------------------
# Read FROM out of the Dockerfile instead of hardcoding it, so a Dependabot
# bump to fedora:44 doesn't leave this watching fedora:43 forever.
base=$(awk 'tolower($1) == "from" { print $2; exit }' "$DOCKERFILE")
[ -n "$base" ] || { log "No FROM line found in $DOCKERFILE"; exit 1; }

# Fedora's containers-common sets unqualified-search-registries, and skopeo
# refuses to guess between them without a TTY to prompt at. Qualify short
# names ourselves so `FROM fedora:43` resolves the same way the build does.
ref="$base"
case "$ref" in
    */*) ;;
    *) ref="library/$ref" ;;
esac
case "$ref" in
    *.*/* | *:*/* | localhost/*) ;;
    *) ref="docker.io/$ref" ;;
esac

base_digest=$(skopeo inspect "docker://$ref" | jq -r '.Digest') || base_digest=""
log "Base $ref: ${base_digest:-<unreadable>}"

# --- What's published -------------------------------------------------------
creds=()
if [ -n "${GHCR_USER:-}" ]; then
    creds=(--creds "$GHCR_USER:${GHCR_TOKEN:-}")
fi

# A missing image means the first ever run. A registry hiccup is
# indistinguishable from it at this point, and both want the same answer:
# build. A redundant build costs a few CI minutes; a skipped one ships a
# stale editor until someone notices.
published=$(skopeo inspect "${creds[@]}" "docker://$IMAGE:$TAG" 2>/dev/null) || published=""
if [ -n "$published" ]; then
    cur_upstream=$(jq -r '(.Labels // {})["dp.upstream.version"] // ""' <<<"$published")
    cur_base=$(jq -r '(.Labels // {})["dp.base.digest"] // ""' <<<"$published")
else
    cur_upstream=""
    cur_base=""
fi
log "Published $TAG: upstream=${cur_upstream:-<none>} base=${cur_base:-<none>}"

# --- Verdict ----------------------------------------------------------------
reason=""
if [ "${FORCE:-false}" = "true" ]; then
    reason="forced"
elif [ -z "$published" ]; then
    reason="no published $TAG image, or registry unreachable"
elif [ "$upstream" != "$cur_upstream" ]; then
    reason="VS Code ${cur_upstream:-<none>} -> $upstream"
elif [ -n "$base_digest" ] && [ "$base_digest" != "$cur_base" ]; then
    reason="$ref rebuilt upstream"
fi

if [ -n "$reason" ]; then
    stale=yes
    log "STALE: $reason"
else
    stale=no
    log "Current: nothing upstream has moved"
fi

printf 'stale=%s\n' "$stale"
printf 'reason=%s\n' "${reason:-up to date}"
printf 'upstream_version=%s\n' "$upstream"
printf 'base_digest=%s\n' "$base_digest"
