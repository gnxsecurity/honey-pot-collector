#!/bin/bash

##########################################
####           [GENERAL]              ####
##########################################
# By:  gnXsecurity.com  [github.com/gnxsecurity/honey-pot-collector]

# This [gnx-honey-collector] gets executed by [gnx-honey-monitor] when an attempted connection is made to a monitored port.
# It will add the offending IP address to the collection, log the event and exit.

##########################################
####           [variables]            ####
##########################################

# Define some patterns separated by comma to exclude from adding to the collection. (default is common internal/bogon ranges)
WHITE_LIST="^192\.,^172\.,^127\.,^10\.,^224\.,^240\.,^255\."


##########################################
####           [MAIN]               ####
##########################################

# Small pause for flooding purposes.
sleep 0.5

# Looop through our whitelisted IP addresses and delete if a match isf ound
if [ -n "$NCAT_REMOTE_ADDR" ] ; then
    for patregex in ${WHITE_LIST//,/ } ; do 
        TO_BLOCK=$(echo $NCAT_REMOTE_ADDR | sed "/$patregex/d") &> /dev/null
        if [ -z "$TO_BLOCK" ] ; then
            echo -e "$(date +%D-%R:%S) $SELF_NAME[$SELF_PID]: [WARN] IP address[$NCAT_REMOTE_ADDR] is in the WHITE_LIST, skipping..." >> $LOGFILE
            exit 1
        fi
    done

    if [ -n "$TO_BLOCK" ] ; then

        echo -e "$(date +%D-%R:%S) $SELF_NAME[$SELF_PID]: [NOTICE] detected connection from [$NCAT_REMOTE_ADDR] on port [$NCAT_LOCAL_PORT] adding to collection..." >> $LOGFILE
        echo "$TO_BLOCK" >> $OUTPUT_FILE
    fi
fi

# Whatever is sent to stdout will be returned to the connecting client, depending on what they connected with.  Feel free to edit/add.
echo "Connection successful, yet reset by peer."
exit 0
