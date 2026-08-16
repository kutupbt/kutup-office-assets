#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

LOCK_PATH=${1:-assets.lock.json}
OUTPUT_PATH=${2:-output/onlyoffice}

fail() {
  echo "error: $*" >&2
  exit 1
}

for command_name in curl jq sha256sum sha512sum unzip find sort xargs; do
  command -v "$command_name" >/dev/null 2>&1 || fail "missing command: $command_name"
done

jq -e '.schema_version == 1' "$LOCK_PATH" >/dev/null || fail "unsupported lock schema"

if [[ -e "$OUTPUT_PATH" ]] && find "$OUTPUT_PATH" -mindepth 1 -print -quit | grep -q .; then
  fail "output path must be absent or empty: $OUTPUT_PATH"
fi

WORK_PATH=$(mktemp -d)
trap 'rm -rf -- "$WORK_PATH"' EXIT
ASSEMBLY_PATH="$WORK_PATH/onlyoffice"
mkdir -p "$ASSEMBLY_PATH/dist/v9" "$ASSEMBLY_PATH/dist/x2t" \
  "$ASSEMBLY_PATH/templates" "$ASSEMBLY_PATH/LICENSES"

download_checked() {
  local label=$1
  local url=$2
  local expected_size=$3
  local expected_sha512=$4
  local expected_sha256=$5
  local destination=$6
  local download_target=$destination
  local cached_file=""

  if [[ -n "${ASSET_DOWNLOAD_CACHE:-}" ]]; then
    mkdir -p "$ASSET_DOWNLOAD_CACHE"
    cached_file="$ASSET_DOWNLOAD_CACHE/$expected_sha512"
    if [[ -f "$cached_file" ]]; then
      echo "Using cached $label"
      download_target="$cached_file"
    else
      download_target="$ASSET_DOWNLOAD_CACHE/$expected_sha512.partial"
    fi
  fi

  if [[ ! -f "$destination" ]]; then
    echo "Downloading $label"
    curl --fail --location --continue-at - --proto '=https' --tlsv1.2 --retry 3 \
      --output "$download_target" "$url"
  fi

  if [[ -n "$expected_size" ]]; then
    local actual_size
    actual_size=$(wc -c <"$download_target" | tr -d ' ')
    if [[ "$actual_size" != "$expected_size" ]]; then
      rm -f -- "$download_target"
      fail "$label size mismatch: expected $expected_size, got $actual_size"
    fi
  fi

  if ! printf '%s  %s\n' "$expected_sha512" "$download_target" | \
    sha512sum --check --status; then
    rm -f -- "$download_target"
    fail "$label SHA-512 mismatch"
  fi

  if [[ -n "$expected_sha256" ]]; then
    if ! printf '%s  %s\n' "$expected_sha256" "$download_target" | \
      sha256sum --check --status; then
      rm -f -- "$download_target"
      fail "$label SHA-256 mismatch"
    fi
  fi

  if [[ -n "$cached_file" ]]; then
    if [[ "$download_target" != "$cached_file" ]]; then
      mv "$download_target" "$cached_file"
    fi
    cp "$cached_file" "$destination"
  fi
}

validate_zip_paths() {
  local archive=$1
  if unzip -Z1 "$archive" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
    fail "unsafe path in archive: $archive"
  fi
}

EDITOR_ARCHIVE="$WORK_PATH/editor.zip"
download_checked \
  "OnlyOffice editor" \
  "$(jq -er '.editor.artifact_url' "$LOCK_PATH")" \
  "$(jq -er '.editor.size' "$LOCK_PATH")" \
  "$(jq -er '.editor.sha512' "$LOCK_PATH")" \
  "$(jq -er '.editor.sha256' "$LOCK_PATH")" \
  "$EDITOR_ARCHIVE"
validate_zip_paths "$EDITOR_ARCHIVE"
unzip -q "$EDITOR_ARCHIVE" -d "$ASSEMBLY_PATH/dist/v9"
printf '%s\n' "$(jq -er '.editor.version' "$LOCK_PATH")" >"$ASSEMBLY_PATH/dist/v9/.version"

X2T_ARCHIVE="$WORK_PATH/x2t.zip"
download_checked \
  "x2t WASM" \
  "$(jq -er '.x2t.artifact_url' "$LOCK_PATH")" \
  "$(jq -er '.x2t.size' "$LOCK_PATH")" \
  "$(jq -er '.x2t.sha512' "$LOCK_PATH")" \
  "" \
  "$X2T_ARCHIVE"
validate_zip_paths "$X2T_ARCHIVE"
unzip -q "$X2T_ARCHIVE" -d "$ASSEMBLY_PATH/dist/x2t"
printf '%s\n' "$(jq -er '.x2t.version' "$LOCK_PATH")" >"$ASSEMBLY_PATH/dist/x2t/.version"

while IFS=$'\t' read -r name url sha512; do
  download_checked "template $name" "$url" "" "$sha512" "" \
    "$ASSEMBLY_PATH/templates/$name"
done < <(jq -er '.templates.files[] | [.name, .url, .sha512] | @tsv' "$LOCK_PATH")
printf '%s\n' "$(jq -er '.templates.version' "$LOCK_PATH")" >"$ASSEMBLY_PATH/templates/.version"

while IFS=$'\t' read -r name url sha512; do
  download_checked "license $name" "$url" "" "$sha512" "" \
    "$ASSEMBLY_PATH/LICENSES/$name"
done < <(jq -er '.licenses[] | [.name, .url, .sha512] | @tsv' "$LOCK_PATH")

cat >"$ASSEMBLY_PATH/dist/v9/document_editor_service_worker.js" <<'EOF'
// Kutup no-op service worker. The pinned editor registers this path, but its
// cache worker is not part of the CryptPad client-only release archive.
self.addEventListener('install', () => self.skipWaiting())
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()))
EOF

SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
"$SCRIPT_PATH/write-metadata.sh" "$LOCK_PATH" "$ASSEMBLY_PATH" \
  ./ONLYOFFICE-ADDITIONAL-TERMS.md
"$SCRIPT_PATH/verify-assets.sh" "$LOCK_PATH" "$ASSEMBLY_PATH"

mkdir -p "$(dirname -- "$OUTPUT_PATH")"
if [[ -d "$OUTPUT_PATH" ]]; then
  rmdir "$OUTPUT_PATH"
fi
mv "$ASSEMBLY_PATH" "$OUTPUT_PATH"
echo "Assembled verified assets at $OUTPUT_PATH"
