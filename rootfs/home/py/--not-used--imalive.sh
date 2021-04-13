#!/bin/bash

# kx1t: this script was moved in its entirety to /etc/services.d/imalive/run
# so we can run it as a recurring S6 service instead of having CRON invoke it

IFS=-

host=$HOSTNAME ;
set $host;
# kx1t: retrieve station name from $FEEDER_KEY docker env variable
st=${FEEDER_KEY%%:*}
ts=$(date "+%s")
#echo " $st Current Time : $ts"
STATUS=$(curl -s http://mg2.adsbnetwork.com:/rtools/pyalive.php?stid=$st);
if [[ `echo $STATUS | grep -o "404"` = "404" ]] ; then
	echo  " IAmLive : C est Rate $ts ";
	exit 2;
else
	if [[ -z  $STATUS ]]; then
		logger  " IAmLive : Pas De Reseau  $ts ";
		exit 2;
	else
		#	echo " lfey = $STATUS"
		set $STATUS;
		status=$1;
		rts=$2 ;
		rts=$((rts-10));
		#	 echo " Ts = $ts $status Rts = $rts";
		if [[ $ts -lt $rts ]];then
			# kx1t: using s6 to restart the service
			s6-svc -r /var/run/s6/services/radarvirtuel
			# /usr/bin/RestartANfeeder.sh majdate;
			logger  " IAmLive : RestartANfeeder Avec Date  $ts ";
			echo    " IAmLive : RestartANfeeder Avec Date  $ts ";
			# kx1t: added warning that Docker image cannot resync NTP
			echo "Warning - Feeder script is attempting to resync NTP, but this cannot done from without a Docker container."
		else
			if test "$status" = ko; then
				# kx1t: using s6 to restart the service
				s6-svc -r /var/run/s6/services/radarvirtuel
				# /usr/bin/RestartANfeeder.sh;
				logger  " IAmLive : RestartANfeeder Sans Date $ts  ";
				echo    " IAmLive : RestartANfeeder Sans Date $ts  ";
			fi;
		fi;
	fi;
fi;
