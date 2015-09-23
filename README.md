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
dcos kafka update 0..2 --options num.io.threads=16,num.partitions=12
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
docker run -i -t brndnmtthws/presto-cli --server coordinator-presto.marathon.mesos:12000 --catalog cassandra --schema twitter
```

# Execute some SQL queries with Presto

```sql
# Count all the tweets
SELECT count(1) FROM tweets;

# Get a list of recent tweets
SELECT substr(tweet_text, 1, 40) AS tweet_text, batchtime, score FROM tweets ORDER BY batchtime DESC LIMIT 20;

# Count tweets by score
SELECT count(1) AS tweet_count, score FROM tweets GROUP BY score ORDER BY score;

# Count of tweets by language
SELECT json_extract(tweet, '$.lang') AS languages, count(*) AS count FROM tweets GROUP BY json_extract(tweet, '$.lang') ORDER BY count desc;

# Count of tweets by location
SELECT
  json_extract(tweet, '$.user.location') AS location,
  count(*) AS tweet_count
FROM tweets
WHERE
  json_extract(tweet, '$.user.location') IS NOT NULL AND
  length(json_format(json_extract(tweet, '$.user.location'))) > 2
GROUP BY json_extract(tweet, '$.user.location')
ORDER BY tweet_count DESC
LIMIT 100;

# Most prolific tweeters
SELECT
  json_extract(tweet, '$.user.screen_name') AS screen_name,
  count(*) AS tweet_count
FROM tweets
WHERE
  json_extract(tweet, '$.user.screen_name') IS NOT NULL AND
  length(json_format(json_extract(tweet, '$.user.screen_name'))) > 2
GROUP BY json_extract(tweet, '$.user.screen_name')
ORDER BY tweet_count DESC
LIMIT 100;

# Most retweeted
WITH 
top_retweets AS (
  SELECT
    json_extract_scalar(tweet, '$.retweeted_status.id') AS id,
    count(*) as retweet_count
  FROM tweets
  WHERE
    json_extract(tweet, '$.retweeted_status') IS NOT NULL
  GROUP BY json_extract_scalar(tweet, '$.retweeted_status.id')
),
all_tweets AS (
  SELECT tweet_text, 
  json_extract_scalar(tweet, '$.retweeted_status.id') AS id
  FROM tweets
),
joined_tweets AS (
SELECT
  all_tweets.tweet_text as tweet_text,
  top_retweets.retweet_count AS retweet_count,
  top_retweets.id AS id
FROM top_retweets
LEFT JOIN all_tweets
ON top_retweets.id = all_tweets.id
ORDER BY retweet_count DESC
)
SELECT arbitrary(tweet_text) AS tweet_text, arbitrary(retweet_count) AS retweet_count FROM joined_tweets
GROUP BY id
LIMIT 100;
```
