# iot-demo [![Build Status](https://travis-ci.org/mesosphere/iot-demo.svg?branch=master)](https://travis-ci.org/mesosphere/iot-demo)

# iot-demo
IoT - It's the thing you want! And so here's a full-stack demo.

# Sequence of commands (to run)

```
# Start DCOS services:
dcos package install cassandra
dcos package install kafka

# When Kafka is healthy, add brokers
dcos kafka add 0..2
dcos kafka start 0..2
# Show Kafka cluster status
dcos kafka status

# Add tweet producers
# NOTE: Add twitter API keys first!
dcos marathon app add marathon/tweet-producer-bieber.json
dcos marathon app add marathon/tweet-producer-trump.json

# Start Presto:
dcos marathon group add marathon/presto.json

# Last, run tweet consumer
dcos marathon app add marathon/tweet-consumer.json

# Run presto-cli:
docker run -i -t brndnmtthws/presto-cli --server presto-coordinator-prest.marathon.mesos:12000 --catalog cassandra --schema twitter

# Execute a SQL query:
select substr(tweet_text, 1, 40) as tweet_text, batchtime, score from tweets order by batchtime desc limit 20;
```
