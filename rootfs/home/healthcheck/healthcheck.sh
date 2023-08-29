#!/command/with-contenv bash

# Import healthchecks-framework
source /opt/healthchecks-framework/healthchecks.sh

# HEALTHLIMIT is the number of error lines that can be in run/imalive/errors before things go UNHEALTHY
HEALTHLIMIT=20

APPNAME="$(hostname)/healthcheck"

touch /run/imalive/errors
if [[ "$(cat /run/imalive/errors | wc -l)" -ge "$HEALTHLIMIT" ]]
then
    echo "[$APPNAME][$(date)] Abnormal death count for RadarVirtuel is $(cat /run/imalive/errors | wc -l): UNHEALTHY (>= $HEALTHLIMIT)"
    exit 1
else
    [[ "$VERBOSE" == "ON" ]] && echo "[$APPNAME][$(date)] Abnormal death count for RadarVirtuel is $(cat /run/imalive/errors | wc -l): HEALTHY (< $HEALTHLIMIT)"
fi
exit 0
