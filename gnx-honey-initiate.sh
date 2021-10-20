#!/bin/bash

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
####           [MAIN]               ####
##########################################

# Loops through each port and starts a collector instance the background via screen.
for startup in $PORTS ; do
  echo -e "[INFO] starting honeypot on port $startup...."
  screen -A -m -d -S gnx-hpot-$startup bash gnx-honey-monitor.sh $startup $NETWORK_PROTOCOL &
  sleep 2
done

