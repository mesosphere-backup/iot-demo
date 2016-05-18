#!/bin/bash

#
#IOT Demo Wrapper
#v1.1
#Last Modified: 2016-04-21
#Author: Keith McClellan


# Init

help()
{
cat << EOF
usage: $0 options

This script will initialize and execute your IOT Demo

Only use flag -m if you want to change the URL for your DCOS CLI.  This flag will override any preset URL in your variables.conf file.

OPTIONS:
-h,-?   Show this message
-m	IP of DCOS Master
-l  hostname of ELB

SAMPLE SYNTAX

./iot_demo.sh -m [DCOS Master IP] -l [ELB Hostname]
./iot_demo.sh -m 192.168.1.1 -l keithmccl-publicsl-9tt7w0dah1z4-541736414.us-west-2.elb.amazonaws.com

EOF
}

PROJECT_DIR=`dirname "$0"`/..
cd "$PROJECT_DIR"

source ./etc/variables.conf

while getopts “hm:l:v” OPTION
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
cat ./etc/variables.conf
#set variable expansion on for rest of script
set -v
fi

#set echo on for rest of script
set -e

#Print commands and their arguments as they are executed
set -x

date

if [[ -z $DCOS_MASTER_IP ]]
then
echo "Using Previously Configured DCOS Cluster"
else
dcos config set core.dcos_url http://$DCOS_MASTER_IP
dcos auth login
fi


##Check to see if DCOS CLI can see DCOS Master
dcos task
if [[ $? -ne 0 ]]
then
echo "DCOS CLI is not configured properly - can't reach host"
exit
fi


DCOS_URL=`dcos config show core.dcos_url`
DCOS_URL=${1-$DCOS_URL}

echo "Base install on cluster "$DCOS_URL

# Use base marathon for packages.
# E.g. Kafka doesn't work with nested Marathon.
dcos config unset marathon.url || true

rm -f ./marathon/zeppelin.json

sed "/elb_hostname/ s/elb_hostname/$DCOS_ELB_HOST/" ./marathon/zeppelin_template.json >> ./marathon/zeppelin.json

echo "Ready to begin, press [Enter] to proceed"
read
echo "Start DCOS services:"
dcos package install --yes marathon-lb
dcos package install --yes cassandra
dcos package install --yes kafka --options=kafka-options.json
dcos marathon app add ./marathon/zeppelin.json
echo "Start DCOS services: done"
echo "Wait for services to start, then press [Enter] to proceed with creating Tweet producer(s) and consumer."
read

rm ./etc/config.yml

sed "/TWEET_OAUTH_CONSUMER_KEY/ s/\: \"\"/\: \"$TWEET_OAUTH_CONSUMER_KEY\"/;/TWEET_OAUTH_CONSUMER_SECRET/ s/\: \"\"/\: \"$TWEET_OAUTH_CONSUMER_SECRET\"/;/TWEET_OAUTH_TOKEN_KEY/ s/\: \"\"/\: \"$TWEET_OAUTH_TOKEN_KEY\"/;/TWEET_OAUTH_TOKEN_SECRET/ s/\: \"\"/\: \"$TWEET_OAUTH_TOKEN_SECRET\"/" ./etc/config_template.yml >> ./etc/config.yml

function update_group() {
local group_id="$1"
local group_json="$2"

if dcos marathon group show "$group_id" >/dev/null; then
echo "- updating $group_id: "
dcos marathon group update --force "$group_id" <"$group_json"
echo "- updating $group_id: done"
else
echo "- creating $group_id: "
dcos marathon group add "$group_json"
echo "- creating $group_id: done"
fi
}

mkdir -p target

date
echo "install on cluster "`dcos config show core.dcos_url`

echo "Preparing Marathon group configuration: "
./bin/prepare-config.py marathon/demo.yml >target/demo.json
echo "Preparing Marathon group configuration: done"

echo "Sending configuration to Marathon: "
update_group "/demo" "target/demo.json"
echo "Sending configuration to Marathon: done"

date

cat << EOF

URL of Notebook to load:
https://raw.githubusercontent.com/mesosphere/iot-demo/master/zeppelin-notebook.json

Java Dependencies to Load:

com.google.guava:guava:16.0.1
org.apache.spark:spark-streaming-kafka_2.10:1.6.1
com.datastax.spark:spark-cassandra-connector_2.10:1.6.0-M2

EOF



