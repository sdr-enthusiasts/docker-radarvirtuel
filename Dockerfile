
FROM debian:stable-slim

ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Copy needs to be here to prevent github actions from failing.
# SSL Certs are pre-loaded into the rootfs via a job in github action:
# See: "Copy CA Certificates from GitHub Runner to Image rootfs" in deploy.yml
COPY rootfs/ /

RUN set -x && \
# define packages needed for installation and general management of the container:
    TEMP_PACKAGES=() && \
    KEPT_PACKAGES=() && \
    KEPT_PACKAGES+=(gawk) && \
    TEMP_PACKAGES+=(gnupg2) && \
    TEMP_PACKAGES+=(file) && \
    KEPT_PACKAGES+=(curl) && \
    KEPT_PACKAGES+=(ca-certificates) && \
    KEPT_PACKAGES+=(procps nano aptitude netcat) && \
    KEPT_PACKAGES+=(psmisc) && \
# Git and net-tools are needed to install and run @Mikenye's HealthCheck framework
    TEMP_PACKAGES+=(git) && \
    KEPT_PACKAGES+=(net-tools) && \
# Install all these packages:
    apt-get update && \
    apt-get install --force-yes -y \
        ${KEPT_PACKAGES[@]} \
        ${TEMP_PACKAGES[@]} && \
#
# Link to the arch-appropriate version of ANfeeder:
    [[ ! -f /home/py/ANfeeder-raspy-$(dpkg --print-architecture) ]] && { echo "Error - target arch not supported!" ; exit 1; } || \
    ln -sf /home/py/ANfeeder-raspy-$(dpkg --print-architecture) /home/py/ANfeeder && \
#
# Install @Mikenye's HealthCheck framework (https://github.com/mikenye/docker-healthchecks-framework)
mkdir -p /opt && \
git clone \
      --depth=1 \
      https://github.com/mikenye/docker-healthchecks-framework.git \
      /opt/healthchecks-framework \
      && \
    rm -rf \
      /opt/healthchecks-framework/.git* \
      /opt/healthchecks-framework/*.md \
      /opt/healthchecks-framework/tests \
      && \
#
# install S6 Overlay
    curl -s https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay.sh | sh && \
#
# Clean up
    apt-get remove -y ${TEMP_PACKAGES[@]} && \
    apt-get autoremove -o APT::Autoremove::RecommendsImportant=0 -o APT::Autoremove::SuggestsImportant=0 -y && \
    apt-get clean -y && \
    rm -rf /src/* /tmp/* /var/lib/apt/lists/* && \
#
# Do some stuff for kx1t's convenience:
    echo "alias dir=\"ls -alsv\"" >> /root/.bashrc && \
    echo "alias nano=\"nano -l\"" >> /root/.bashrc

ENTRYPOINT [ "/init" ]

# Add healthcheck
HEALTHCHECK --start-period=60s --interval=600s CMD /home/healthcheck/healthcheck.sh
