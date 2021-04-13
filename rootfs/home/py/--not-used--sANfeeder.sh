#!/bin/bash
#
# kx1t: this file is no longer needed as the execution of the script is now managed by S6 as a service
# see /etc/services.d/radarvirtuel/run
/home/py/ANFeeder/ANfeeder-raspy -i $FEEDER_KEY   -d mg2.adsbnetwork.com:50046  -s $SOURCE_HOST &
