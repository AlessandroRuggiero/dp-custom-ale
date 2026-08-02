#!/bin/bash
set -e

# Provide fallback IDs (defaults to 1000) if PUID/PGID are not set
USER_ID=${PUID:-1000}
GROUP_ID=${PGID:-1000}

# Get current IDs
CURRENT_UID=$(id -u penguin)
CURRENT_GID=$(id -g penguin)

# Modify the internal 'penguin' user and group to map to the host's UID/GID
# Only run if they are different to avoid "no changes" messages and save startup time
if [ "$CURRENT_GID" != "$GROUP_ID" ]; then
    groupmod -o -g "$GROUP_ID" penguin
fi

if [ "$CURRENT_UID" != "$USER_ID" ]; then
    usermod -o -u "$USER_ID" penguin
fi

# Ensure the home directory is owned by the newly mapped user
# Only run chown if we actually changed the UID or GID to avoid slow startups
if [ "$CURRENT_GID" != "$GROUP_ID" ] || [ "$CURRENT_UID" != "$USER_ID" ]; then
    chown -R penguin:penguin /home/penguin
fi

# Drop root privileges and execute the main container command as 'penguin'
# "$@" represents the arguments passed by Docker (e.g., 'bash', 'npm start', etc.)
exec gosu penguin "$@"