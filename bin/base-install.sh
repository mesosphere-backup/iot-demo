#!/bin/bash

#
# Base setup using DCOS.
#
# Installs kafka and cassandra.
#
#
# Make sure that your dcos command line is configured correctly for the cluster!


# Init

help()
{
cat << EOF
usage: $0 options

IOT Demo Wrapper
v1.0.1
Last Modified: 2015-10-16
Author: Keith McClellan

This script will initialize and execute your IOT Demo

Only use flag -m if you want to change the URL for your DCOS CLI.  This flag will override any preset URL in your variables.conf file.


OPTIONS:
-h,-?   Show this message
-m	IP of DCOS Master
-l  hostname of ELB

SAMPLE SYNTAX

./iot_demo.sh -m [DCOS Master IP] -l [ELB Hostname]
./iot_demo.sh -m 192.168.1.1 -m keithmccl-publicsl-9tt7w0dah1z4-541736414.us-west-2.elb.amazonaws.com

EOF
}

while getopts “hm:v” OPTION
    do
    case $OPTION in
        h)
            help
            exit 1
            ;;
        m)
            DCOS_MASTER_IP=$OPTARG
            ;;
        l)
            DCOS_ELB_HOST=$OPTARG
            ;;
        v)
            VERBOSE=1
            ;;
        ?)
            help
            exit
            ;;
    esac
done

source variables.conf 

# Make sure root isn't running our script
if [[ $EUID -eq 0 ]]; then
echo "This script cannot be run as root" 1>&2
exit 1
fi

if [[ $VERBOSE = 1 ]]
then
echo "Variables are set to:"
echo "DCOS_MASTER_IP = "$DCOS_MASTER_IP
echo "DCOS_ELB_HOST = "$DCOS_ELB_HOST
set -v #set variable expansion on for rest of script
fi

set -e
set -x

date

DCOS_URL=`dcos config show core.dcos_url`
DCOS_URL=${1-$DCOS_URL}
dcos config set core.dcos_url "$DCOS_URL"
MARATHON_URL="$DCOS_URL/service/marathon011"
echo "base install on cluster "$DCOS_URL

# Use base marathon for packages.
# E.g. Kafka doesn't work with nested Marathon.
dcos config unset marathon.url || true

echo "Start DCOS services:"
dcos package install --yes marathon-lb
dcos package install --yes cassandra
dcos package install --yes kafka --options=kafka-options.json
echo "Start DCOS services: done"

#echo "Start Marathon on Marathon: "
#if ! http --check-status "$MARATHON_URL/v2/apps" > /dev/null; then
#    dcos package install --yes --package-version=v0.11.0-RC5 --options=marathon/marathon-config.json marathon
#    while ! http --check-status "$MARATHON_URL/v2/apps" > /dev/null; do
#        echo "Retrying in 3s"
#        sleep 3
#    done
#    echo "- started"
#else
#    echo "- already running"
#fi
#dcos config set marathon.url "$MARATHON_URL/"
#echo "Start Marathon on Marathon: done"
