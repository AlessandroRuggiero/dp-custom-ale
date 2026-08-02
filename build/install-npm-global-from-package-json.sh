#!/usr/bin/env sh

set -eu

usage() {
  echo "Usage: $0 <package-name> <package.json path|dir> [--cleanup]" >&2
}

if [ "${1:-}" = "" ] || [ "${2:-}" = "" ]; then
  usage
  exit 1
fi

package_name="$1"
input_path="$2"
cleanup="${3:-}"

manifest_path="$input_path"
if [ -d "$manifest_path" ]; then
  manifest_path="$manifest_path/package.json"
fi

if [ ! -f "$manifest_path" ]; then
  echo "package.json not found at: $manifest_path" >&2
  exit 1
fi

version="$(node -e "
const manifestPath = process.argv[1];
const packageName = process.argv[2];
const manifest = require(manifestPath);
const version = (manifest.dependencies && manifest.dependencies[packageName])
  || (manifest.devDependencies && manifest.devDependencies[packageName]);
if (!version) process.exit(2);
process.stdout.write(String(version));
" "$manifest_path" "$package_name")"

npm install -g "${package_name}@${version}"

if [ "$cleanup" = "--cleanup" ]; then
  if [ -d "$input_path" ]; then
    rm -rf "$input_path"
  else
    rm -f "$manifest_path"
  fi
fi
