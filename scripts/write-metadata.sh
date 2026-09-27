#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

LOCK_PATH=${1:-assets.lock.json}
ASSET_PATH=${2:-output/onlyoffice}
NOTICE_PATH=${3:-ONLYOFFICE-ADDITIONAL-TERMS.md}

fail() {
  echo "error: $*" >&2
  exit 1
}

for command_name in find jq sha512sum sort xargs; do
  command -v "$command_name" >/dev/null 2>&1 || fail "missing command: $command_name"
done

jq -e '.schema_version == 1' "$LOCK_PATH" >/dev/null || fail "unsupported lock schema"
[[ -d "$ASSET_PATH/LICENSES" ]] || fail "missing license directory: $ASSET_PATH/LICENSES"
[[ -s "$NOTICE_PATH" ]] || fail "missing ONLYOFFICE notice: $NOTICE_PATH"

cat >"$ASSET_PATH/LICENSE.md" <<'EOF'
# Client-side office asset licenses

This directory contains the ONLYOFFICE browser editor and x2t WebAssembly
converter, originally developed by Ascensio System SIA, and CryptPad's
empty-document templates.

These are **modified versions** of ONLYOFFICE: CryptPad adapted them to run
entirely in the browser, and Kutup maintains its own changes. They are built
from Kutup's forks (kutupbt/onlyoffice-editor, kutupbt/onlyoffice-x2t-wasm);
the changes and their dates are listed in `LICENSES/*-MODIFICATIONS.md`, and
the source is at the commits recorded in `SOURCE.json`.

They are distributed under the GNU AGPL version 3 with ONLYOFFICE's
additional terms (summarised in `LICENSES/ONLYOFFICE-ADDITIONAL-TERMS.md`,
stated in full in each component's `LICENSE` under `LICENSES/`), with CC0 and
CC BY-SA components where identified. Artifact hashes are in `SOURCE.json`.

ONLYOFFICE is a trademark of Ascensio System SIA. Kutup's packaging is
unofficial and is not affiliated with or endorsed by ONLYOFFICE.
EOF

cp "$NOTICE_PATH" "$ASSET_PATH/LICENSES/ONLYOFFICE-ADDITIONAL-TERMS.md"

jq '{
  schema_version,
  bundle_version,
  created,
  onlyoffice_additional_terms,
  editor: (.editor | del(.sha256, .sha512, .size, .destination)),
  x2t: (.x2t | del(.sha512, .size, .destination)),
  templates: (.templates | del(.files)),
  licenses: [.licenses[] | {name, source, url, sha512}]
}' "$LOCK_PATH" >"$ASSET_PATH/SOURCE.json"

jq '{
  spdxVersion: "SPDX-2.3",
  dataLicense: "CC0-1.0",
  SPDXID: "SPDXRef-DOCUMENT",
  name: ("kutup-office-assets-" + .bundle_version),
  documentNamespace: ("https://github.com/kutupbt/kutup-office-assets/sbom/" + .bundle_version),
  creationInfo: {
    created: .created,
    creators: ["Organization: Kutup", "Tool: kutup-office-assets"]
  },
  hasExtractedLicensingInfos: [
    {
      licenseId: "LicenseRef-ONLYOFFICE-Additional-Terms",
      extractedText: "ONLYOFFICE additional terms under AGPLv3 Section 7, stated in each component LICENSE (LICENSES/editor-sdkjs-LICENSE, editor-web-apps-LICENSE, x2t-core-LICENSE) and summarised in LICENSES/ONLYOFFICE-ADDITIONAL-TERMS.md; modifications in LICENSES/*-MODIFICATIONS.md.",
      name: "ONLYOFFICE AGPLv3 Section 7 additional terms"
    }
  ],
  packages: [
    {
      SPDXID: "SPDXRef-Editor",
      name: .editor.name,
      versionInfo: .editor.version,
      downloadLocation: .editor.artifact_url,
      licenseConcluded: "NOASSERTION",
      licenseDeclared: "AGPL-3.0-only AND LicenseRef-ONLYOFFICE-Additional-Terms AND CC-BY-SA-4.0",
      checksums: [
        {algorithm: "SHA256", checksumValue: .editor.sha256},
        {algorithm: "SHA512", checksumValue: .editor.sha512}
      ]
    },
    {
      SPDXID: "SPDXRef-X2T",
      name: .x2t.name,
      versionInfo: .x2t.version,
      downloadLocation: .x2t.artifact_url,
      licenseConcluded: "NOASSERTION",
      licenseDeclared: "AGPL-3.0-only AND LicenseRef-ONLYOFFICE-Additional-Terms AND CC-BY-SA-4.0",
      checksums: [{algorithm: "SHA512", checksumValue: .x2t.sha512}]
    },
    {
      SPDXID: "SPDXRef-Templates",
      name: .templates.name,
      versionInfo: .templates.version,
      downloadLocation: .templates.source_url,
      licenseConcluded: "AGPL-3.0-or-later",
      licenseDeclared: "AGPL-3.0-or-later"
    }
  ]
}' "$LOCK_PATH" >"$ASSET_PATH/SBOM.spdx.json"

rm -f -- "$ASSET_PATH/FILES.sha512"
(
  cd "$ASSET_PATH"
  find . -type f ! -name FILES.sha512 -print0 | LC_ALL=C sort -z | \
    xargs -0 sha512sum >FILES.sha512
)
