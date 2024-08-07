#!/command/with-contenv bash
#shellcheck shell=bash

#---------------------------------------------------------------------------------------------
# Copyright (C) 2023-2024, Ramon F. Kolb (kx1t) and contributors
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, either version 3 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with this program.
# If not, see <https://www.gnu.org/licenses/>.
#---------------------------------------------------------------------------------------------

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
