# ─────────────────────────────────────────────────────────────
# Dockerfile — docker-radarvirtuel v2.0
# Version     : v2.2 — 2026-06-09
# Description : RadarVirtuel Docker feeder v2.2
#               feeder_radarvirtuel.py — POST /api/feed avec tagging station
#               Base: sdr-enthusiasts/docker-baseimage:wreadsb
# Author      : kx1t <kx1t@kx1t.com>
# Org. Author : Laurent Duval <laurent.duval@adsbnetwork.com>   
# ─────────────────────────────────────────────────────────────
FROM ghcr.io/sdr-enthusiasts/docker-baseimage:wreadsb

LABEL maintainer="kx1t@kx1t.com"
LABEL org.opencontainers.image.title="docker-radarvirtuel v2"
LABEL org.opencontainers.image.description="RadarVirtuel ADS-B feeder v2.2"
LABEL org.opencontainers.image.url="https://radarvirtuel.com"
LABEL org.opencontainers.image.version="2.2"

ARG VERSION_REPO="sdr-enthusiasts/docker-radarvirtuel"
ARG VERSION_BRANCH="##BRANCH##"

ENV RV_AIRCRAFT_URL="file:///run/readsb/aircraft.json"

RUN apt-get update -q && \
    apt-get install -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -o Dpkg::Options::="--force-confold" -y --no-install-recommends  --no-install-suggests \
        python3-requests && \
    #
    { [[ "${VERSION_BRANCH:0:1}" == "#" ]] && VERSION_BRANCH="main" || true; } && \
    echo "$(TZ=UTC date +%Y%m%d-%H%M%S)_$(curl -ssL "https://api.github.com/repos/$VERSION_REPO/commits/$VERSION_BRANCH" | awk '{if ($1=="\"sha\":") {print substr($2,2,7); exit}}')_$VERSION_BRANCH" > /.CONTAINER_VERSION && \
    #
    # Clean up
    # apt-get remove -q -y ${TEMP_PACKAGES[@]} && \
    apt-get autoremove -q -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -y && \
    apt-get clean -q -y && \
    rm -rf /src /tmp/* /var/lib/apt/lists/* && \
    #
    # Do some stuff for kx1t's convenience:
    echo "alias dir=\"ls -alsv\"" >> /root/.bashrc && \
    echo "alias nano=\"nano -l\"" >> /root/.bashrc && \
    mkdir -p /data /opt/feeder_rv

COPY rootfs/ /


VOLUME ["/data"]

ENV RV_INTERVAL=5
ENV RV_AIRCRAFT_URL=file:///run/readsb/aircraft.json 
ENV MLAT_SERVER=mlat.adsbnetwork.com:50000

HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD grep -q "OK" /var/log/feeder_rv.log 2>/dev/null || exit 1
