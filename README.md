# iot-demo [![Build Status](https://travis-ci.org/mesosphere/iot-demo.svg?branch=master)](https://travis-ci.org/mesosphere/iot-demo)

IoT - It's the thing you want! And so here's a full-stack demo.

This demo shows you how to setup a service on DCOS that

* streams tweets using the twitter stream API to [Kafka](http://kafka.apache.org)
* processes those streams from Kafka using [Spark](http://spark.apache.org)
* stores the enriched data into [Cassandra](http://cassandra.apache.org)
* and make the data queryable easily via SQL by using [Presto](https://prestodb.io)

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
dcos package install cassandra
dcos package install kafka

# When Kafka is healthy, add brokers
dcos kafka broker add 0..2
dcos kafka broker update 0..2 --options num.io.threads=16,num.partitions=6,default.replication.factor=2
dcos kafka broker start 0..2
# Show Kafka cluster status
dcos kafka broker list
```

# Adjust the configuration

* Copy `etc/config_template.yml` to `etc/config.yml`
* Create a Twitter account with API keys ([see here for details](https://dev.twitter.com/oauth/overview/application-owner-access-tokens))
* Insert your credentials into the configuration file

# Install the tweet producers/consumers and presto 

Execute `./bin/install.sh`.

NOTE: This calls a python 3 script with yaml and jinja modules. You can use pip and homebrew to update your system.

`brew install python3`

`pip3 install pyyaml`

`pip3 install jinja2`

## Background

The `install.sh` script uses the `./bin/prepare-config.py` script to convert YAML configuration files into
 JSON digestible by Marathon.
 
It produces two Marathon groups that are then send to the Marathon REST API for deployment:

* `target/presto.json` for all of presto.
* `target/demo.json` for the tweet producers and the tweet consumer.

The prepare-config.py supports some special processing instructions inside of your YAML files to

* include other files (`!include`)
* use configuration values (`!cfg_str`, `!cfg_path`)
* or to loop over configuration and apply a template (`!map`)

# Execute some SQL queries with Presto

Make sure that your load balancer is configured correctly to work with websockets. For the standard setup of DCOS
 on AWS you need to change the listener type in the AWS console:
 
* Go to the AWS EC2 console and choose the region that you launched your cluster in.
* Navigate to "Load Balancers"
* Search for the "Public Slave" load balancer configuration of your cluster.
* Use "Actions / Edit Listeners" and configure the protocol for port 80 to TCP instead of HTTP.

Connect to your public node with your browser.

Now you should have a presto shell in your browser. Copy & Paste does not work in all browsers. It worked
for me in Chrome. Here are some sample queries to run:

```sql
-- Count all the tweets
SELECT count(1) FROM tweets;

-- Get a list of recent tweets
SELECT substr(tweet_text, 1, 40) AS tweet_text, batchtime, score FROM tweets ORDER BY batchtime DESC LIMIT 20;

-- Count tweets by score
SELECT count(1) AS tweet_count, query, score FROM tweets GROUP BY score, query ORDER BY query, score;

-- Count of tweets by language
SELECT json_extract_scalar(tweet, '$.lang') AS languages, count(*) AS count FROM tweets GROUP BY json_extract_scalar(tweet, '$.lang') ORDER BY count DESC;

-- Count of tweets by location
SELECT
  json_extract_scalar(tweet, '$.user.location') AS location,
  count(*) AS tweet_count
FROM tweets
WHERE
  json_extract_scalar(tweet, '$.user.location') IS NOT NULL AND
  length(json_extract_scalar(tweet, '$.user.location')) > 0
GROUP BY json_extract_scalar(tweet, '$.user.location')
ORDER BY tweet_count DESC
LIMIT 100;

-- Most prolific tweeters
SELECT
  json_extract_scalar(tweet, '$.user.screen_name') AS screen_name,
  count(*) AS tweet_count
FROM tweets
WHERE
  json_extract_scalar(tweet, '$.user.screen_name') IS NOT NULL AND
  length(json_extract_scalar(tweet, '$.user.screen_name')) > 0
GROUP BY json_extract_scalar(tweet, '$.user.screen_name')
ORDER BY tweet_count DESC
LIMIT 100;

-- Most retweeted
WITH
top_retweets AS (
  SELECT
    json_extract_scalar(tweet, '$.retweeted_status.id') AS id,
    count(*) AS retweet_count
  FROM tweets
  WHERE
    json_extract(tweet, '$.retweeted_status') IS NOT NULL
  GROUP BY json_extract_scalar(tweet, '$.retweeted_status.id')
),
all_tweets AS (
  SELECT tweet_text,
  json_extract_scalar(tweet, '$.retweeted_status.id') AS id
  FROM tweets
)
SELECT
  arbitrary(all_tweets.tweet_text) AS tweet_text,
  arbitrary(top_retweets.retweet_count) AS retweet_count
FROM top_retweets
LEFT JOIN all_tweets
ON top_retweets.id = all_tweets.id
GROUP BY top_retweets.id
ORDER BY retweet_count DESC
LIMIT 100;
```

# Use manually started shells to examine the data

SSH into one of the masters or worker nodes in the cluster, and try either cqlsh or Presto:

```console
# Run presto-cli:
docker run -i -t mesosphere/presto-cli --server coordinator-presto.marathon.mesos:12000 --catalog cassandra --schema twitter

# Run cqlsh:
docker run -i -t --net=host --entrypoint=/usr/bin/cqlsh spotify/cassandra cassandra-dcos-node.cassandra.dcos.mesos 9160
```
