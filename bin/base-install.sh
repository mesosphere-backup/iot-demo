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
