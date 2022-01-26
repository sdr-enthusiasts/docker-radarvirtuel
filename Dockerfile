FROM ghcr.io/fredclausen/docker-baseimage:python

ENV URL_MLAT_CLIENT_REPO="https://github.com/adsbxchange/mlat-client.git" \
    PRIVATE_MLAT="false" \
    MLAT_INPUT_TYPE="dump1090"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Copy needs to be here to prevent github actions from failing.
# SSL Certs are pre-loaded into the rootfs via a job in github action:
# See: "Copy CA Certificates from GitHub Runner to Image rootfs" in deploy.yml
# COPY root_certs/ /

RUN set -x && \
# define packages needed for installation and general management of the container:
    TEMP_PACKAGES=() && \
    KEPT_PACKAGES=() && \
#    KEPT_PACKAGES+=(procps nano aptitude netcat) && \
    KEPT_PACKAGES+=(procps nano aptitude) && \
    KEPT_PACKAGES+=(psmisc) && \
# Git and net-tools are needed to install and run @Mikenye's HealthCheck framework
    TEMP_PACKAGES+=(git) && \
# These are needed to compile and install the mlat_client:
    TEMP_PACKAGES+=(build-essential) && \
    TEMP_PACKAGES+=(debhelper) && \
    #TEMP_PACKAGES+=(python-dev) && \
    TEMP_PACKAGES+=(python3-dev) && \
    TEMP_PACKAGES+=(python3-distutils-extra) && \
    #TEMP_PACKAGES+=(dh-python) && \
#
# Install all these packages:
    apt-get update -q -y && \
    apt-get install -q --force-yes -y \
        ${KEPT_PACKAGES[@]} \
        ${TEMP_PACKAGES[@]} && \

# Compile and Install the mlat_client
    mkdir -p /git && \
    pushd /git && \
        git clone https://github.com/mutability/mlat-client.git && \
        cd mlat-client && \
#        dpkg-buildpackage -b -uc && \
#        cd .. && \
#        dpkg -i mlat-client_*.deb && \
        BRANCH_MLAT_CLIENT=$(git tag --sort="-creatordate" | head -1) && \
        git checkout "$BRANCH_MLAT_CLIENT" && \
        ./setup.py install && \
    popd && \
    rm -rf /git && \

#
# Clean up
    apt-get remove -q -y ${TEMP_PACKAGES[@]} && \
    apt-get autoremove -q -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -y && \
    apt-get clean -y && \
    rm -rf /src /tmp/* /var/lib/apt/lists/* && \
#
# Do some stuff for kx1t's convenience:
    echo "alias dir=\"ls -alsv\"" >> /root/.bashrc && \
    echo "alias nano=\"nano -l\"" >> /root/.bashrc

COPY rootfs/ /

RUN set -x && \
#
# Link to the arch-appropriate version of ANfeeder:
    [[ ! -f /home/py/ANfeeder-raspy-$(dpkg --print-architecture) ]] && { echo "Error - target arch not supported for $(dpkg --print-architecture) !" ; exit 1; } || \
    ln -sf /home/py/ANfeeder-raspy-$(dpkg --print-architecture) /home/py/ANfeeder
#

ENTRYPOINT [ "/init" ]

# Add healthcheck
HEALTHCHECK --start-period=60s --interval=600s CMD /home/healthcheck/healthcheck.sh
