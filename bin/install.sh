#!/bin/bash

#
# Installs the demo application. Assumes that base-install.sh has been run before.
#

set -e

PROJECT_DIR=`dirname "$0"`/..
cd "$PROJECT_DIR"

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
./bin/prepare-config.py marathon/presto.yml >target/presto.json
echo "Preparing Marathon group configuration: done"

echo "Sending configuration to Marathon: "
update_group "/demo" "target/demo.json"
update_group "/presto" "target/presto.json"
echo "Sending configuration to Marathon: done"

date