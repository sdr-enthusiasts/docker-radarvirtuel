FROM ghcr.io/sdr-enthusiasts/docker-baseimage:mlatclient AS downloader
RUN --mount=type=bind,source=/source/,target=/source/ \
    gcc -static /source/anfeeder.c -o /ANfeeder -lm -Ofast -W

FROM ghcr.io/sdr-enthusiasts/docker-baseimage:base

ENV PRIVATE_MLAT="false" \
    MLAT_INPUT_TYPE="dump1090"

ARG VERSION_REPO="sdr-enthusiasts/docker-radarvirtuel" \
VERSION_BRANCH="##BRANCH##"

SHELL ["/bin/bash", "-x", "-o", "pipefail", "-c"]
RUN --mount=type=bind,from=downloader,source=/,target=/downloader/ \
    # define packages needed for installation and general management of the container:
    TEMP_PACKAGES=() && \
    KEPT_PACKAGES=() && \
    KEPT_PACKAGES+=(procps) && \
    KEPT_PACKAGES+=(psmisc) && \
    # Needed to run the mlat_client:
    KEPT_PACKAGES+=(python3-minimal) && \
    KEPT_PACKAGES+=(python3-pkg-resources) && \
    # Needed for the new ImAlive:
    KEPT_PACKAGES+=(tcpdump) && \
    #
    # Install all these packages:
    apt-get update -q -y && \
    apt-get install -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -o Dpkg::Options::="--force-confold" -y --no-install-recommends  --no-install-suggests \
    ${KEPT_PACKAGES[@]} \
    ${TEMP_PACKAGES[@]} && \
    #
    # Install mlatclient that was copied in from downloader image
    tar zxf /downloader/mlatclient.tgz -C / && \
    # test mlat-client
    /usr/bin/mlat-client --help > /dev/null && \
    #
    # Copy anfeeder:
    mkdir -p /home/py/ && \
    cp /downloader/ANfeeder /home/py/ANfeeder && \
    # remove pycache introduced by testing mlat-client
    find /usr | grep -E "/__pycache__$" | xargs rm -rf || true && \
    # Add Container Version
    [[ "${VERSION_BRANCH:0:1}" == "#" ]] && VERSION_BRANCH="main" || true && \
    echo "$(TZ=UTC date +%Y%m%d-%H%M%S)_$(curl -ssL https://api.github.com/repos/$VERSION_REPO/commits/$VERSION_BRANCH | awk '{if ($1=="\"sha\":") {print substr($2,2,7); exit}}')_$VERSION_BRANCH" > /.CONTAINER_VERSION && \
    #
    # Clean up
    # apt-get remove -q -y ${TEMP_PACKAGES[@]} && \
    apt-get autoremove -q -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -y && \
    apt-get clean -q -y && \
    rm -rf /src /tmp/* /var/lib/apt/lists/* && \
    #
    # Do some stuff for kx1t's convenience:
    echo "alias dir=\"ls -alsv\"" >> /root/.bashrc && \
    echo "alias nano=\"nano -l\"" >> /root/.bashrc

COPY rootfs/ /

# Add healthcheck
HEALTHCHECK --start-period=60s --interval=600s CMD /home/healthcheck/healthcheck.sh
