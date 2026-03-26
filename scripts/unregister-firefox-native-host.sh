#!/usr/bin/env bash
set -euo pipefail

manifest_dir="${HOME}/.mozilla/native-messaging-hosts"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest-dir)
      manifest_dir="${2:?missing value for --manifest-dir}"
      shift 2
      ;;
    -h|--help)
      cat <<'EOF'
Usage: dyx-unregister-firefox-host [--manifest-dir DIR]
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

manifest_path="${manifest_dir}/app.dyx.native_host.json"
rm -f "${manifest_path}"
echo "Removed Firefox native host manifest at ${manifest_path}"
