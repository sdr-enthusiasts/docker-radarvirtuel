#!/bin/bash

# kx1t: no ntp service within Docker
#if [[ $1 = "majdate" ]] ; then
#        logger " RestartANfeeder   majDate $1";
#       service ntp stop
#        ntpdate 0.pool.ntp.org
#        service ntp start
#fi;

if ( pgrep ANfeeder-raspy 1>/dev/null );
then
     killall ANfeeder-raspy
fi
cd /home/py/ANFeeder
./sANfeeder.sh  &

#if [ $(date +%H%M) == 0030 ]; then
#	service ntp stop
#	ntpdate 0.pool.ntp.org
#	service ntp start
#fi
