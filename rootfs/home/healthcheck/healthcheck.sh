#!/usr/bin/with-contenv bash
#shellcheck shell=bash

# HEALTHLIMIT is the number of error lines that can be in run/imalive/errors when things go UNHEALTHY
HEALTHLIMIT=10

APPNAME="$(hostname)/healthcheck"

touch /run/imalive/errors
if [[ "$(wc -l /run/imalive/errors)" -ge "$HEALTHLIMIT" ]]
then
    echo "[$APPNAME][$(date)] Abnormal death count for RadarVirtuel is $(wc -l /run/imalive/errors): UNHEALTHY (>= $HEALTHLIMIT)"
    exit 1
else
    [[ "$VERBOSE" == "ON" ]] && echo "[$APPNAME][$(date)] Abnormal death count for RadarVirtuel is $(wc -l /run/imalive/errors): HEALTHY (< $HEALTHLIMIT)"
fi
