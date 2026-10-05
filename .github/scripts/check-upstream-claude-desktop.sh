#!/usr/bin/env bash
#
# Is the published `claude-desktop` image stale?
#
# Claude Desktop arrives via `apt install claude-desktop` from Anthropic's apt
# repo, so a new release never changes a tracked file and Dependabot cannot
# see it. This compares the newest version in the repo index against the
# label on the currently published image and prints a verdict.
#
# Unlike check-upstream-code.sh it deliberately ignores in-place rebuilds of
# the base tag: the image is large, and only a new app version is worth a
# rebuild.
#
# Needs curl, jq and skopeo, which the ubuntu-latest runner already has.
# Locally:
#
#   IMAGE=ghcr.io/alessandroruggiero/dp-custom-ale/claude-desktop \
#     .github/scripts/check-upstream-claude-desktop.sh
#
# Everything human-readable goes to stderr; stdout carries only `key=value`
# lines, so CI can append it straight to $GITHUB_OUTPUT.

set -euo pipefail

log() { printf '%s\n' "$*" >&2; }

: "${IMAGE:?IMAGE must be set (e.g. ghcr.io/owner/repo/claude-desktop)}"
TAG="${TAG:-main}"
# amd64 because that is the only platform the workflow builds.
INDEX="${INDEX:-https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages}"

# --- Upstream Claude Desktop ------------------------------------------------
upstream=$(curl -fsS "$INDEX" \
    | awk '/^Package: / { pkg = $2 } /^Version: / && pkg == "claude-desktop" { print $2 }' \
    | sort -V | tail -1)
if [ -z "$upstream" ]; then
    log "No claude-desktop version in $INDEX. Failing loudly: a silent"
    log "empty answer here reads as 'up to date' and freezes the app."
    exit 1
fi
log "Upstream Claude Desktop: $upstream"

# --- What's published -------------------------------------------------------
creds=()
if [ -n "${GHCR_USER:-}" ]; then
    creds=(--creds "$GHCR_USER:${GHCR_TOKEN:-}")
fi

# As in check-upstream-code.sh: a missing image and a registry hiccup look
# the same here, and both get a build.
published=$(skopeo inspect "${creds[@]}" "docker://$IMAGE:$TAG" 2>/dev/null) || published=""
if [ -n "$published" ]; then
    cur_upstream=$(jq -r '(.Labels // {})["dp.upstream.version"] // ""' <<<"$published")
else
    cur_upstream=""
fi
log "Published $TAG: upstream=${cur_upstream:-<none>}"

# --- Verdict ----------------------------------------------------------------
reason=""
if [ "${FORCE:-false}" = "true" ]; then
    reason="forced"
elif [ -z "$published" ]; then
    reason="no published $TAG image, or registry unreachable"
elif [ "$upstream" != "$cur_upstream" ]; then
    reason="Claude Desktop ${cur_upstream:-<none>} -> $upstream"
fi

if [ -n "$reason" ]; then
    stale=yes
    log "STALE: $reason"
else
    stale=no
    log "Current: no new Claude Desktop release"
fi

printf 'stale=%s\n' "$stale"
printf 'reason=%s\n' "${reason:-up to date}"
printf 'upstream_version=%s\n' "$upstream"
