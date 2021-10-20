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
####             [LOGGER]             ####
##########################################

function log_it(){
    if [[ "$1" =~ "INFO" ]] ; then
        echo -e "$(date +%D-%R:%S) $(basename $0)[$SELF_PID]: $1" >> $LOGFILE
    else
        echo -e "$(date +%D-%R:%S) $(basename $0)[$SELF_PID]: $1" | tee -a $LOGFILE
    fi
}

##########################################
####             [PRIMER]             ####
##########################################
# Leave these default

readonly PROTOCOL="$(echo $PROTOCOL | awk '{print tolower($0)}')"

log_it "[INFO] checking system for netstat or ss capabilities..."
if [ "$(which netstat &> /dev/null ; echo $?)" -ne "0" ] ; then
    readonly C_METHOD="$(which ss)"
else
    readonly C_METHOD="$(which netstat)"
fi

if [ -z "$METHOD" ] ; then
    log_it "[ERROR] selected method [$METHOD] either doesn't exist or is blank, please check and try again"
    exit 1
fi

##########################################
####            [FUNCTIONS]           ####
##########################################

function is_port_available(){
    if [ $($C_METHOD -ltun | grep -E "*:$LISTEN_PORT[[:space:]]" &> /dev/null ; echo $?) -eq "0" ]; then
        STATE="1" ; false
    else
        STATE="" ; true
    fi
}

function pront(){
    echo -e "$GREEN$(printf '%25s\n' | tr ' ' -)$1$(printf '%25s\n' | tr ' ' -)$RESET"
}

function gen_stats(){
    echo "$(printf '%125s\n' | tr ' ' -)" >> $LOGFILE
    if ! compgen -G "$OUTPUT_DIR/ip-collection-*" > /dev/null ; then
        log_it "[ERROR] no suitable files exist in directory [$OUTPUT_DIR] to generate statistics"
        exit 1
    elif [[ "$(cat $OUTPUT_DIR/ip-collection-* | wc -l)" -lt "10" ]] ; then
        log_it "[ERROR] not enough data currently to generate statistics, as less than 10 records exist..."
        exit 1 
    fi       

    pront "all-time activity"
    echo -e "All-time total hits: $RED[$(cat $OUTPUT_DIR/ip-collection-* | wc -l)] $RESET"
    echo -e "Sources with multiple hits: $RED[$(cat $OUTPUT_DIR/ip-collection-* | sort | uniq -c | sort -nr | grep -v -e '[[:blank:]]1[[:space:]][[:digit:]]' | wc -l)]$RESET"
    echo -e "Unique sources with multiple at least one hit: $RED[$(cat $OUTPUT_DIR/ip-collection-* | uniq -c | wc -l)]$RESET"

    IFS=$'\n'
    pront "Top sources connected"
    for xhit in $(cat $OUTPUT_DIR/ip-collection-* | sort | uniq -c | sed 's/^ *//' | sort -nr | head -n 10) ; do
      echo "$RED$(echo $xhit | awk '{print $1}') $RESET $(echo $xhit | awk '{print $2}') "
    done
    IFS=" "

    pront "Top ports accessed"
    echo "$RED$(du -hsx $OUTPUT_DIR/* | grep "ip-collection" | sort -rn | awk '{print $2}' | grep -Eo '[0-9]{1,9}' | head -n 5) $RESET"
    exit 0

}

##########################################
####          [Sanity Checks]         ####
##########################################

log_it "[INFO] checking port [$LISTEN_PORT] format for accuracy..."
if [ -z "$LISTEN_PORT" ] ; then
    log_it "[ERROR] required configuration field [LISTEN_PORT] empty, please update and try again..." 
    exit 1
elif [[ "$LISTEN_PORT" == "stats" ]]; then
    echo "$(printf '%125s\n' | tr ' ' -)" >> $LOGFILE
    log_it "[INFO] executed with [$LISTEN_PORT] command line argument, running statistics function..."
    gen_stats
elif ! [[ "$LISTEN_PORT" =~ ^[0-9]+$ ]] ; then
    log_it "[ERROR] the listen port [$LISTEN_PORT] is invalid and contains non-numeric characters, please update and try again"
    exit 1
fi

if [ -z "$PROTOCOL" ] ; then
    log_it "[ERROR] required command line flag [PROTOCOL] not set, defaulting to TCP."
    readonly PROTOCOL="tcp"
fi

log_it "[INFO[ checking $PROTOCOL availability port using [$C_METHOD]..."
if is_port_available ; then
    STATE=""
else
    log_it "[ERROR] selected port [$LISTEN_PORT] is currently in use..."
    exit 1
fi

if [ ! -d "$OUTPUT_DIR" ] ; then
    log_it "[NOTICE] output directory [$OUTPUT_DIR], does not exist, creating now..."
    mkdir -p $OUTPUT_DIR
fi

log_it "[INFO] passed all initial sanity checks, continuing..."

##########################################
####              [MAIN]              ####
##########################################

export OUTPUT_FILE LOGFILE SELF_PID SELF_NAME


function tcp_pot(){
    while [ -z "$STATE" ] ; do
    # Note:  You can add a '-k' flag which will prevent reloading, but introduces flooding risk.
        $NET_METH -v --send-only -4ntl -w 1 -p $LISTEN_PORT -c ./$RESPONSE_SCRIPT
        is_port_available
        # Create some separation between events to prevent flooding
        sleep 1.5
    done
}


function udp_pot(){
    while [ -z "$STATE" ] ; do
        # Note:  You can add a '-k' flag which will prevent reloading, but introduces flooding risk.
        $NET_METH -v --send-only -4ntl -w 1 -u -p $LISTEN_PORT -c ./$RESPONSE_SCRIPT
        is_port_available
        # Create some separation between events to prevent flooding
        sleep 1.5
    done
}


log_it "[NOTICE] starting $NET_METH via protocol [$PROTOCOL] listening on port $LISTEN_PORT.."

if [ "$PROTOCOL" == "udp" ] ; then
    udp_pot
elif [[ "$PROTOCOL" == "tcp" ]] ; then
    tcp_pot
else
    log_it "[ERROR] invalid protocol [$PROTOCOL] provided at runtime, fix and try again..."
    exit 1
fi
