#!/usr/bin/env bash
set -euo pipefail

extension_id="extension@dyx.app"
manifest_dir="${HOME}/.mozilla/native-messaging-hosts"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
package_root="$(cd -- "${script_dir}/.." && pwd)"

default_host_bin() {
  if [[ -n "${DYX_NATIVE_HOST_BIN:-}" ]]; then
    printf '%s\n' "${DYX_NATIVE_HOST_BIN}"
    return
  fi
  if [[ -x "${script_dir}/dyx-native-host" ]]; then
    printf '%s\n' "${script_dir}/dyx-native-host"
    return
  fi
  if [[ -x "${package_root}/bin/dyx-native-host" ]]; then
    printf '%s\n' "${package_root}/bin/dyx-native-host"
    return
  fi
  if [[ -x "${package_root}/libexec/dyx-native-host" ]]; then
    printf '%s\n' "${package_root}/libexec/dyx-native-host"
    return
  fi
  if [[ -x "${package_root}/zig-out/bin/dyx-native-host" ]]; then
    printf '%s\n' "${package_root}/zig-out/bin/dyx-native-host"
    return
  fi
  if [[ -x "${package_root}/../zig-out/bin/dyx-native-host" ]]; then
    printf '%s\n' "${package_root}/../zig-out/bin/dyx-native-host"
    return
  fi
  printf '%s\n' "${package_root}/libexec/dyx-native-host"
}

default_template_path() {
  if [[ -n "${DYX_FIREFOX_HOST_TEMPLATE:-}" ]]; then
    printf '%s\n' "${DYX_FIREFOX_HOST_TEMPLATE}"
    return
  fi
  if [[ -f "${package_root}/share/dyx/native-messaging/firefox/app.dyx.native_host.json.in" ]]; then
    printf '%s\n' "${package_root}/share/dyx/native-messaging/firefox/app.dyx.native_host.json.in"
    return
  fi
  printf '%s\n' "${package_root}/packaging/native-messaging/firefox/app.dyx.native_host.json.in"
}

host_bin="$(default_host_bin)"
template_path="$(default_template_path)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host-bin)
      host_bin="${2:?missing value for --host-bin}"
      shift 2
      ;;
    --extension-id)
      extension_id="${2:?missing value for --extension-id}"
      shift 2
      ;;
    --manifest-dir)
      manifest_dir="${2:?missing value for --manifest-dir}"
      shift 2
      ;;
    -h|--help)
      cat <<'EOF'
Usage: dyx-register-firefox-host [--host-bin PATH] [--extension-id ID] [--manifest-dir DIR]
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ ! -x "${host_bin}" ]]; then
  echo "DYX native host not found or not executable: ${host_bin}" >&2
  exit 1
fi

if [[ ! -f "${template_path}" ]]; then
  echo "Firefox native-host template not found: ${template_path}" >&2
  exit 1
fi

mkdir -p "${manifest_dir}"
manifest_path="${manifest_dir}/app.dyx.native_host.json"

host_bin_abs="$(realpath "${host_bin}")"
python3 - "${template_path}" "${manifest_path}" "${host_bin_abs}" "${extension_id}" <<'PY'
import json
import pathlib
import sys

template_path = pathlib.Path(sys.argv[1])
manifest_path = pathlib.Path(sys.argv[2])
host_path = sys.argv[3]
extension_id = sys.argv[4]

template = template_path.read_text(encoding="utf-8")
template = template.replace("@HOST_PATH@", host_path).replace("@EXTENSION_ID@", extension_id)
parsed = json.loads(template)
manifest_path.write_text(json.dumps(parsed, indent=2) + "\n", encoding="utf-8")
PY

echo "Installed Firefox native host manifest at ${manifest_path}"
