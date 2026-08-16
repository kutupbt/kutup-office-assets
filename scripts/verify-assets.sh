#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

LOCK_PATH=${1:-assets.lock.json}
ASSET_PATH=${2:-output/onlyoffice}

fail() {
  echo "error: $*" >&2
  exit 1
}

for command_name in find jq sha512sum; do
  command -v "$command_name" >/dev/null 2>&1 || fail "missing command: $command_name"
done

jq -e '.schema_version == 1' "$LOCK_PATH" >/dev/null || fail "unsupported lock schema"
[[ -d "$ASSET_PATH" ]] || fail "asset path does not exist: $ASSET_PATH"

required_files=(
  dist/v9/.version
  dist/v9/web-apps/apps/api/documents/api.js
  dist/v9/web-apps/apps/documenteditor/main/index.html
  dist/v9/web-apps/apps/spreadsheeteditor/main/index.html
  dist/v9/web-apps/apps/presentationeditor/main/index.html
  dist/v9/web-apps/apps/common/main/resources/img/header/header-logo_s.svg
  dist/v9/document_editor_service_worker.js
  dist/x2t/.version
  dist/x2t/x2t.js
  dist/x2t/x2t.wasm
  templates/.version
  templates/oocell_base.js
  templates/oodoc_base.js
  templates/ooslide_base.js
  LICENSE.md
  LICENSES/ONLYOFFICE-ADDITIONAL-TERMS.md
  SOURCE.json
  SBOM.spdx.json
  FILES.sha512
)

for relative_path in "${required_files[@]}"; do
  [[ -s "$ASSET_PATH/$relative_path" ]] || fail "missing required file: $relative_path"
done

[[ "$(<"$ASSET_PATH/dist/v9/.version")" == "$(jq -er '.editor.version' "$LOCK_PATH")" ]] || \
  fail "editor version marker mismatch"
[[ "$(<"$ASSET_PATH/dist/x2t/.version")" == "$(jq -er '.x2t.version' "$LOCK_PATH")" ]] || \
  fail "x2t version marker mismatch"
[[ "$(<"$ASSET_PATH/templates/.version")" == "$(jq -er '.templates.version' "$LOCK_PATH")" ]] || \
  fail "template version marker mismatch"

while IFS=$'\t' read -r name sha512; do
  printf '%s  %s\n' "$sha512" "$ASSET_PATH/templates/$name" | \
    sha512sum --check --status || fail "template hash mismatch: $name"
done < <(jq -er '.templates.files[] | [.name, .sha512] | @tsv' "$LOCK_PATH")

while IFS=$'\t' read -r name sha512; do
  [[ -s "$ASSET_PATH/LICENSES/$name" ]] || fail "missing license: $name"
  printf '%s  %s\n' "$sha512" "$ASSET_PATH/LICENSES/$name" | \
    sha512sum --check --status || fail "license hash mismatch: $name"
done < <(jq -er '.licenses[] | [.name, .sha512] | @tsv' "$LOCK_PATH")

if find "$ASSET_PATH" -type l -print -quit | grep -q .; then
  fail "asset tree contains a symbolic link"
fi
if find "$ASSET_PATH" -type f \( -name '*.zip' -o -name '*.tar' -o -name '*.tar.gz' \) \
  -print -quit | grep -q .; then
  fail "asset tree contains an archive residue"
fi

(
  cd "$ASSET_PATH"
  sha512sum --check --quiet FILES.sha512
)

jq -e --arg version "$(jq -er '.bundle_version' "$LOCK_PATH")" \
  '.bundle_version == $version' "$ASSET_PATH/SOURCE.json" >/dev/null || \
  fail "source manifest version mismatch"
jq -e '.spdxVersion == "SPDX-2.3" and (.packages | length == 3) and
  (.hasExtractedLicensingInfos[0].licenseId == "LicenseRef-ONLYOFFICE-Additional-Terms")' \
  "$ASSET_PATH/SBOM.spdx.json" >/dev/null || fail "invalid SPDX manifest"

MAX_KIB=1600000
ACTUAL_KIB=$(du -sk "$ASSET_PATH" | awk '{print $1}')
(( ACTUAL_KIB <= MAX_KIB )) || fail "asset tree exceeds ${MAX_KIB} KiB"

echo "Verified Kutup office assets at $ASSET_PATH"
