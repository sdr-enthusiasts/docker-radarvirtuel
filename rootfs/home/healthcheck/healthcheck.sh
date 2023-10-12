#!/command/with-contenv bash
#shellcheck shell=bash

# Import healthchecks-framework
# shellcheck disable=SC1091
source /opt/healthchecks-framework/healthchecks.sh

# HEALTHLIMIT is the number of error lines that can be in run/imalive/errors before things go UNHEALTHY
HEALTHLIMIT=20

APPNAME="$(hostname)/healthcheck"

touch /run/imalive/errors
#shellcheck disable=SC2002
if [[ "$(cat /run/imalive/errors | wc -l)" -ge "$HEALTHLIMIT" ]]
then
    echo "[$APPNAME][$(date)] Abnormal death count for RadarVirtuel is $(cat /run/imalive/errors | wc -l): UNHEALTHY (>= $HEALTHLIMIT)"
    exit 1
else
    #shellcheck disable=SC2002
    [[ "$VERBOSE" == "ON" ]] && echo "[$APPNAME][$(date)] Abnormal death count for RadarVirtuel is $(cat /run/imalive/errors | wc -l): HEALTHY (< $HEALTHLIMIT)"
fi
exit 0
