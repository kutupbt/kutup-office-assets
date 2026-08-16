FROM --platform=$BUILDPLATFORM alpine:3.22 AS assemble

RUN apk add --no-cache bash coreutils curl findutils jq unzip

WORKDIR /work
COPY assets.lock.json ./assets.lock.json
COPY ONLYOFFICE-ADDITIONAL-TERMS.md ./ONLYOFFICE-ADDITIONAL-TERMS.md
COPY scripts/ ./scripts/

RUN --mount=type=cache,id=kutup-office-downloads,target=/var/cache/kutup-office-downloads,sharing=locked \
    ASSET_DOWNLOAD_CACHE=/var/cache/kutup-office-downloads \
    ./scripts/build-assets.sh ./assets.lock.json /opt/kutup/onlyoffice

FROM scratch

LABEL org.opencontainers.image.title="Kutup client-side office assets" \
      org.opencontainers.image.description="Pinned CryptPad-shaped OnlyOffice browser editor assets for Kutup" \
      org.opencontainers.image.source="https://github.com/kutupbt/kutup-office-assets" \
      org.opencontainers.image.licenses="AGPL-3.0-only AND LicenseRef-ONLYOFFICE-Additional-Terms AND CC-BY-SA-4.0" \
      org.opencontainers.image.version="2026.08.16-cryptpad-v9"

COPY --from=assemble /opt/kutup/onlyoffice/ /opt/kutup/onlyoffice/
