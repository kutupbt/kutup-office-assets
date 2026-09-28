# Kutup office assets

Reproducible packaging for the client-side office editor used by
[Kutup](https://github.com/kutupbt/kutup).

This is an unofficial integration maintained by Kutup. It is not affiliated
with or endorsed by ONLYOFFICE. ONLYOFFICE is a trademark of its respective
owner, and no trademark rights are granted by this repository.

The package combines the OnlyOffice browser editor and the x2t WebAssembly
converter, both built from Kutup's forks
([`kutupbt/onlyoffice-editor`](https://github.com/kutupbt/onlyoffice-editor),
[`kutupbt/onlyoffice-x2t-wasm`](https://github.com/kutupbt/onlyoffice-x2t-wasm))
of CryptPad's builds, with CryptPad's empty-document templates. It does not
contain or run OnlyOffice DocumentServer. Conversion and editing happen in the
browser so Kutup's server remains content-blind.

## Output

The Docker build produces a data-only image with this contract:

```text
/opt/kutup/onlyoffice/
  dist/v9/
  dist/x2t/
  templates/
  LICENSE.md
  LICENSES/
  SOURCE.json
  SBOM.spdx.json
  FILES.sha512
```

Inputs are immutable and hash-verified through `assets.lock.json`. Generated
editor binaries are deliberately not committed to Git.

Build and verify locally:

```sh
docker build --output type=local,dest=.build .
./scripts/verify-assets.sh assets.lock.json \
  .build/opt/kutup/onlyoffice
```

The extracted output is roughly 1.1 GiB. Docker's cache avoids repeating the
download when the lock and build steps have not changed.

## Published image

The public AMD64/ARM64 package is available from GHCR. Consumers must pin its
immutable OCI digest rather than relying on a mutable tag:

```text
ghcr.io/kutupbt/kutup-office-assets@sha256:0f730ad42440b9fbaea8f2189a3c6e9d21278e9ba4cdae1c11ab242c4e004c5f
```

The human-readable tag `2026.09.28-kutup-v9.4` resolves to the same index.
Both platform manifests reference the same architecture-independent static
asset layer.

## Updating

An update must change the lock, source coordinates, applicable licenses,
checksums, SBOM inputs, and Kutup browser evidence together. Never replace an
existing release tag or OCI digest. The ONLYOFFICE attribution, the
modification notices and Kutup's in-editor legal notice must stay in place
(`ONLYOFFICE-ADDITIONAL-TERMS.md`).

## License and sources

Packaging code in this repository is licensed under AGPL-3.0-or-later. The
packaged third-party files retain their own copyright and license terms,
including ONLYOFFICE's Section 7 additional terms and CC BY-SA notices
summarized in `ONLYOFFICE-ADDITIONAL-TERMS.md`. Exact license copies and
corresponding-source coordinates are installed under `/opt/kutup/onlyoffice/`
and enumerated in `assets.lock.json`.

See [NOTICE.md](NOTICE.md) for component ownership and source locations.
