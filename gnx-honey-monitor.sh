#!/bin/bash

##########################################
####           [General]             ####
##########################################
# By:  gnXsecurity.com  [github.com/gnxsecurity/honey-pot-collector]

# At runtime two arguments must be supplied for correct operation.
# TCP example, listening on port 21:  gnx-name.sh 21 tcp
# UDP example, listening on port 161:  gnx-name.sh 161 udp
# When no UDP/TCP argument is provided, will default to TCP.

# It is recommended to not execute this script directly and instead use the startup script.
# This will execute in a detached screen and allows for multiple instnaces on multiple ports.

##########################################
####       [CMD Line Variables]       ####
##########################################
# These get populated at runtime through command line arguments

# Port to listen on for connections (pass in at runtime, or edit here)
LISTEN_PORT="$1"
# Protocol (UDP or TCP).  (pass in at runtime, if not, defaults to TCP)
PROTOCOL="$2"

##########################################
####           [variables]            ####
##########################################
# These can be safely changed despite the readonly setting.

# OUTPUT directory where logs, connectivity files are kept.  Will be created if doesn't exist.  No trailing slash.
readonly OUTPUT_DIR="./output"

# Logfile location, be sure to include / at the end.
readonly LOGFILE="/var/log/gnx-honey.log"

# Location of collector script (default recommended), this gets executed each time a connection is made to record IP information.
readonly RESPONSE_SCRIPT="gnx-honey-collector.sh"

# Method (ncat, netcat/nc, tcpserver), defaults to ncat.
readonly METHOD="ncat"

##########################################
####              [CONST]             ####
##########################################
# Leave these default

# Changing this will break some functionality (such as stats) which relies on a collection per-port.
readonly OUTPUT_FILE="$OUTPUT_DIR/ip-collection-$LISTEN_PORT.txt"

readonly RED=$(tput setaf 1)
readonly GREEN=$(tput setaf 2)
readonly RESET=$(tput sgr0)

readonly NET_METH="$(which $METHOD)"
readonly SELF_PID="$$"
readonly SELF_NAME="$(basename $0)"


##########################################
####             [PRIMER]             ####
##########################################
# Leave these default

readonly PROTOCOL="$(echo $PROTOCOL | awk '{print tolower($0)}')"

if [ "$(which netstat &> /dev/null ; echo $?)" -ne "0" ] ; then
    readonly C_METHOD="$(which ss)"
else
    readonly C_METHOD="$(which netstat)"
fi

##########################################
####            [FUNCTIONS]           ####
##########################################

function is_port_available(){
    log_it "[INFO[ checking $PROTOCOL availability port using [$C_METHOD]..."
    if [ $($C_METHOD -ltun | grep -E "*:$LISTEN_PORT[[:space:]]" &> /dev/null ; echo $?) -eq "0" ]; then
        STATE="1" ; false
    else
        STATE="" ; true
    fi
}

function log_it(){
    echo -e "$(date +%D-%R:%S) $(basename $0)[$SELF_PID] $1" | tee -a $LOGFILE
}

function gen_stats(){
    log_it "[INFO] executed with [$LISTEN_PORT] command line argument, running statistics function..."
    #printf '%120s\n' | tr ' ' -
    
    echo -e "$GREEN$(basename $0) all-time activity....$RESET"
    echo -e "All-time total hits: $RED[$(cat output/ip-list-* | wc -l)] $RESET"
    echo -e "Sources with multiple hits: $RED[$(cat output/ip-list-* | sort | uniq -c | sort -nr | grep -v -e '[[:blank:]]1[[:space:]][[:digit:]]' | wc -l)]$RESET"
    echo -e "Unique sources with multiple at least one hit: $RED[$(cat output/ip-list-* | uniq -c | wc -l)]$RESET"

    IFS=$'\n'
    echo -e "$GREEN$(basename $0) Top 10 sources:"
    for xhit in $(cat output/ip-list-* | sort | uniq -c | sed 's/^ *//' | sort -nr | head -n 10) ; do
      echo "$RED$(echo $xhit | awk '{print $1}') $RESET $(echo $xhit | awk '{print $2}') "
    done
    IFS=" "

    echo -e "$GREEN$(basename $0) Top 5 ports:"
    echo "$RED$(du -hsx $OUTPUT_DIR/* | grep "ip-list" | sort -rn | awk '{print $2}' | grep -Eo '[0-9]{1,9}' | head -n 5) $RESET"

    og_it "[INFO] finished running statistics, exiting..."
    exit 0

}

##########################################
####          [Sanity Checks]         ####
##########################################

if [ -z "$LISTEN_PORT" ] ; then
    log_it "[ERROR] required configuration field [LISTEN_PORT] empty, please update and try again..." 
    exit 1
elif [[ "$LISTEN_PORT" == "stats" ]]; then
    gen_stats
elif ! [[ "$LISTEN_PORT" =~ "^[0-9]+$" ]] ; then
    log_it "[ERROR] the listen port [$LISTEN_PORT] is invalid and contains non-numeric characters, please update and try again"
    exit 1
fi

if [ -z "$PROTOCOL" ] ; then
    log_it "[ERROR] required command line flag [PROTOCOL] not set, defaulting to TCP."
    readonly PROTOCOL="tcp"
fi

if is_port_available ; then
    STATE=""
else
    log_it "[ERROR] selected port [$LISTEN_PORT] is currently in use..."
    exit 1
fi

if [ ! -d "$OUTPUT_DIR" ] ; then
    llog_it "[ERROR] output directory [$OUTPUT_DIR], does not exist, creating now..."
    mkdir -p $OUTPUT_DIR
fi

##########################################
####              [MAIN]              ####
##########################################

export OUTPUT_FILE LOGFILE SELF_PID SELF_NAME


function tcp_pot(){
    log_it "starting $NET_METH on port $LISTEN_PORT.."
    while [ -z "$STATE" ] ; do
	# Note:  You can add a '-k' flag which will prevent reloading, but introduces flooding risk.
        $NET_METH -v --send-only -4ntl -w 1 -p $LISTEN_PORT -c ./$RESPONSE_SCRIPT
        is_port_available
        # Create some separation between events to prevent flooding
        sleep 1.5
    done
}


function udp_pot(){
    log_it "starting $NET_METH on port $LISTEN_PORT.."
    while [ -z "$STATE" ] ; do
        # Note:  You can add a '-k' flag which will prevent reloading, but introduces flooding risk.
        $NET_METH -v --send-only -4ntl -w 1 -u -p $LISTEN_PORT -c ./$RESPONSE_SCRIPT
        is_port_available
        # Create some separation between events to prevent flooding
        sleep 1.5
    done
}

if [ "$PROTOCOL" == "udp" ] ; then
    udp_pot
else
    tcp_pot
fi
