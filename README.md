# iot-demo [![Build Status](https://travis-ci.org/mesosphere/iot-demo.svg?branch=master)](https://travis-ci.org/mesosphere/iot-demo)

IoT - It's the thing you want! And so here's a full-stack demo.

This demo shows you how to setup a service on DCOS that

* streams tweets using the twitter stream API to [Kafka](http://kafka.apache.org)
* processes those streams from Kafka using [Spark](http://spark.apache.org)
* stores the enriched data into [Cassandra](http://cassandra.apache.org)
* and make the data queryable easily via SQL by using [Zeppelin](https://zeppelin.incubator.apache.org/)

There are presentations about this demo:

* [Cassandra summit 2015 - Simplifying Streaming Analytics](http://www.slideshare.net/BrendenMatthews/cassandra-summit-2015-simplifying-streaming-analytics)
  by Brenden Matthews with an emphasis on data processing
* [Hamburg Mesos Meetup - Deploying your Service on DCOS](https://docs.google.com/presentation/d/1skc6-Hb28oyUX-XCeBaSZuMWVndu2A40TL8HeQKw-Dk/edit#slide=id.ge21c9a11a_0_358)
  by Peter Kolloch with an emphasis on deployment of non-trivial services

# Create a DCOS cluster and install the CLI

Follow the instructions [here](https://docs.mesosphere.com/install/createcluster/).

- You'll need enough capacity to run all the services, which may require at least 5 worker nodes
- SSH access to the cluster
- Internet access from inside the cluster

When you open the dashboard, follow the instructions to install the DCOS CLI.

# Install Cassandra and Kafka

You can either execute `./bin/base-install.sh <your DCOS cluster base URL>` or run the commands yourself.

You want to dive in deep and do everything yourself? Then point your DCOS client installation at the correct
cluster and execute the commands below.

## Configure the DCOS CLI

If you just set up your CLI for the first time, you can probably skip this step.

Use `dcos config set core.dcos_url <your DCOS core URL>`, e.g.
`dcos config set core.dcos_url "http://peter-22f-elasticl-1ejv8oa4oyqw8-626125644.us-west-2.elb.amazonaws.com"`.


## Sequence of commands to run with the DCOS CLI

```console
# Start DCOS services:
dcos package install marathon-lb
dcos package install cassandra
dcos package install kafka --options=kafka-options.json

# Check that Cassandra & Kafka are up
dcos cassandra connection
dcos kafka connection
```

# Adjust the configuration

* Copy `etc/config_template.yml` to `etc/config.yml`
* Create a Twitter account with API keys ([see here for details](https://dev.twitter.com/oauth/overview/application-owner-access-tokens))
* Insert your credentials into the configuration file

# Install the tweet producers/consumers

Execute `./bin/install.sh`.

NOTE: This calls a python 3 script with yaml and jinja modules. You can use pip and homebrew to update your system.

`brew install python3`

`pip3 install pyyaml`

`pip3 install jinja2`

## Background

The `install.sh` script uses the `./bin/prepare-config.py` script to convert YAML configuration files into
 JSON digestible by Marathon.

It produces a Marathon group that is then sent to the Marathon REST API for deployment:

* `target/demo.json` for the tweet producers and the tweet consumer.

The prepare-config.py supports some special processing instructions inside of your YAML files to

* include other files (`!include`)
* use configuration values (`!cfg_str`, `!cfg_path`)
* or to loop over configuration and apply a template (`!map`)

# Execute some SQL queries with Zeppelin

Once Zeppelin is running, navigate to the UI and import the notebook from this link:

<https://raw.githubusercontent.com/mesosphere/iot-demo/master/zeppelin-notebook.json>

# Use manually started shells to examine the data

SSH into one of the masters or worker nodes in the cluster, and try cqlsh:

```console
# Run cqlsh:
docker run -ti cassandra:2.2.5 cqlsh node-0.cassandra.mesos
```
