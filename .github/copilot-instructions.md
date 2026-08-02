# Disguised Penguin Repo - Copilot Instructions

This repository manages a collection of Dockerized CLI tools.

## How to add a new tool

When tasked with adding a new tool to this repository, follow these steps:

1. **Create the Dockerfile**: Create a new directory at `build/<tool-name>/` and add a `Dockerfile` inside it. The Dockerfile should start from an appropriate base image.
2. **Setup User / Entrypoint**: 
   - Use the shared `setup-penguin.sh` script to install `gosu` and set up the `penguin` user. Example:
     ```dockerfile
     COPY setup-penguin.sh /usr/local/bin/setup-penguin.sh
     RUN /usr/local/bin/setup-penguin.sh [optional_user_to_rename]
     ```
   - Rely on `entrypoint.sh` for flexible UID/PGID mapping at runtime. Include it at the end of the Dockerfile.
   - Remember to set the working directory to `/workspace` so that the tool runs in the context of the user's mounted workspace.
3. **Update `pkgs.json`**: Add an entry for the new tool in `pkgs.json`.
   - Use the image format `"container": "ghcr.io/<your-username>/<repo-name>/<tool-name>:main"`.
   - Specify necessary `"configmounts"` (e.g. for user configuration directories to persist authentication and settings).
   - Specify `"portmappings"` if the tool runs a local server that needs ports exposed to the host.
4. **Update docker-build-push.yml**: Add to the list of filters in the GitHub Actions workflow to trigger builds for the new tool when relevant files change.
5. Update the `README.md` to include the name of the new tool

## General AI guidelines
- Ensure JSON files (`pkgs.json`, `info.json`) are valid and properly formatted.
- Keep Dockerfiles concise and leverage multi-stage builds if necessary for compiled tools.
- Prefer official installation instructions for the respective tools!
- in the `pkgs.json` file make sure to include all necessary configuration mounts for the tool to function properly (e.g. `~/.config/<tool>` for CLI tools that store settings there). You can also include mounts for cache directories to speed up subsequent runs.
- For tools that run local servers, ensure to specify the correct port mappings in `pkgs.json` so that users can access the service from their host machine. (Even if it is only for authentication flows like Firebase CLI)