# Kutup office assets

Reproducible packaging for the client-side office editor used by
[Kutup](https://github.com/kutupbt/kutup).

This is an unofficial integration maintained by Kutup. It is not affiliated
with or endorsed by ONLYOFFICE. ONLYOFFICE is a trademark of its respective
owner, and no trademark rights are granted by this repository.

The package combines the CryptPad-pinned OnlyOffice browser editor, CryptPad's
x2t WebAssembly converter, and CryptPad's empty-document templates. It does not
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

## Updating

An update must change the lock, source coordinates, applicable licenses,
checksums, SBOM inputs, and Kutup browser evidence together. Never replace an
existing release tag or OCI digest. The visible OnlyOffice logo and attribution
must remain preserved in Kutup.

## License and sources

Packaging code in this repository is licensed under AGPL-3.0-or-later. The
packaged third-party files retain their own copyright and license terms,
including the file-level ONLYOFFICE Section 7 and CC BY-SA notices summarized
in `ONLYOFFICE-ADDITIONAL-TERMS.md`. Exact license copies and
corresponding-source coordinates are installed under `/opt/kutup/onlyoffice/`
and enumerated in `assets.lock.json`.

See [NOTICE.md](NOTICE.md) for component ownership and source locations.
