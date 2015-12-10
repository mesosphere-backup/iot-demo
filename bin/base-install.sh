#!/bin/bash

#
# Base setup using DCOS.
#
# Installs kafka and cassandra.
#

# Make sure that your dcos command line is configured correctly for the cluster!

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
dcos package install --yes cassandra
dcos package install --yes kafka
echo "Start DCOS services: done"

echo "Try to add brokers to kafka and start them (initial errors expected): "
while ! dcos kafka broker add 0..2 --options num.io.threads=16,num.partitions=6,default.replication.factor=2 >/dev/null 2>&1; do
    echo "Retrying in 3s"
    sleep 3
done
dcos kafka broker start 0..2
echo "Try to add brokers to kafka and start them: done"
echo "Kafka status: "
dcos kafka broker list
echo "Base installation done"
date

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
