#!/bin/bash

# Uncomment below to enable debug output
# set -x

##########################################
####           [GENERAL]              ####
##########################################
# By:  gnXsecurity.com  [github.com/gnxsecurity/honey-pot-collector]

# For each port, a lightweight dedicated instance of [gnx-honey-monitor.sh] will be launched.
# This will launch [gnx-honey-monitor.sh] in a detached screen allowing it to run in the background.

##########################################
####           [Variables]            ####
##########################################

# Define the ports to listen on for connections, separated by a space.
# Default is mostly the nmap list of freuqnetly scanned ports, minus common server ports (e.g 22,443, 80).
# Conflicts willbe avoided as ports will be checked for availability before using.
PORTS="20 21 23 25 37 38 3389 8080 445 3306 5900 110 111 137 139 143 5938"

# Supports both tcp and udp, however tcp is recommended.
NETWORK_PROTOCOL="tcp"

##########################################
####             [LOGGER]             ####
##########################################
# The variables in use in logging function get set after executed the monitor.

function log_it(){
        echo -e "$(date +%D-%R:%S) $(basename $0)[$$] $1" | tee -a $LOGFILE
}

##########################################
####           [MAIN]               ####
##########################################

if [ "$1" == "stats" ]; then
    bash gnx-honey-monitor.sh stats
    exit 0
fi

# Loops through each port and starts a collector instance the background via screen.
for startup in $PORTS ; do
    screen -A -m -d -S gnx-hpot-$startup bash gnx-honey-monitor.sh $startup $NETWORK_PROTOCOL &
    if [ "$?" -eq "0" ] ; then
        echo "$(printf '%125s\n' | tr ' ' -)" >> $LOGFILE
        log_it "[INFO] successfully executed the monitor in a background screen labeled [gnx-hpot-$startup]"
    else
        echo "$(printf '%125s\n' | tr ' ' -)" >> $LOGFILE
        log_it "[ERROR] screen exited without an error code [$?], execute with debug and try again"
    fi  
    sleep 2
done
