#!/usr/bin/env bash

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

set -euo pipefail

STATUS_FILE="/tmp/healthstatus"
MAX_WARNING=10
MAX_ERROR=5

if [[ ! -f "$STATUS_FILE" ]]; then
  # status file not yet existing, let's assume everything is fine for now
  echo "Status not yet available"
  exit 0
fi

cat "$STATUS_FILE"

warning_count="$(awk -F',' '$1=="WARNING" { print $3; exit }' "$STATUS_FILE")"
error_count="$(awk -F',' '$1=="ERROR" { print $3; exit }' "$STATUS_FILE")"

[[ "$warning_count" =~ ^[0-9]+$ ]] || warning_count=0
[[ "$error_count" =~ ^[0-9]+$ ]] || error_count=0

if (( warning_count >= MAX_WARNING || error_count >= MAX_ERROR )); then
	exit 1
fi

exit 0
