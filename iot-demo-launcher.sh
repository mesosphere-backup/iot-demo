#!/bin/bash
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

SAMPLE SYNTAX

./iot_demo.sh -m [DCOS Master IP]
./iot_demo.sh -m 192.168.1.1

EOF
}

source variables.conf 
source $DCOS_CLI_PATH/env-setup 

#cleanup previous runs
cp -r $IOT_REPO_LOC/marathon/tweet-producer-bieber.json.bak $IOT_REPO_LOC/marathon/tweet-producer-bieber.json
cp -r $IOT_REPO_LOC/marathon/tweet-producer-trump.json.bak $IOT_REPO_LOC/marathon/tweet-producer-trump.json
rm -f $IOT_REPO_LOC/marathon/tweet-producer-bieber.json.bak
rm -f $IOT_REPO_LOC/marathon/tweet-producer-trump.json.bak

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

if [[ -z $DCOS_MASTER_IP ]]
then
echo "Using Previously Configured DCOS Cluster"
else
dcos config set core.dcos_url http://$DCOS_MASTER_IP
fi

# MASTER_IP=`echo $DCOS_MASTER_URL| sed -e 's/^http:\/\///g' -e 's/^https:\/\///g'`

if [[ $VERBOSE = 1 ]]
then
echo "Variables are set to:" 
echo "DCOS_MASTER_IP = "$DCOS_MASTER_IP
cat variables.conf
set -x #set echo on for rest of script
set -v #set variable expansion on for rest of script
fi

##Check to see if DCOS CLI can see DCOS Master
dcos task
if [[ $? -ne 0 ]]
then
    echo "DCOS CLI is not configured properly - can't reach host"
    exit
fi

ssh core@$DCOS_MASTER_IP -i $SSH_KEY "ls"
if [[ $? -ne 0 ]]
then
echo "Can't SSH to Master, check SSH Key"
exit
fi

## Modify tweet producers


sed -i .bak "/TWEET_OAUTH_CONSUMER_KEY/ s/\:\"\"/\:\"$TWEET_OAUTH_CONSUMER_KEY\"/;/TWEET_OAUTH_CONSUMER_SECRET/ s/\:\"\"/\:\"$TWEET_OAUTH_CONSUMER_SECRET\"/;/TWEET_OAUTH_TOKEN_KEY/ s/\:\"\"/\:\"$TWEET_OAUTH_TOKEN_KEY\"/;/TWEET_OAUTH_TOKEN_SECRET/ s/\:\"\"/\:\"$TWEET_OAUTH_TOKEN_SECRET\"/" $IOT_REPO_LOC/marathon/tweet-producer-bieber.json

sed -i .bak "/TWEET_OAUTH_CONSUMER_KEY/ s/\:\"\"/\:\"$TWEET_OAUTH_CONSUMER_KEY\"/;/TWEET_OAUTH_CONSUMER_SECRET/ s/\:\"\"/\:\"$TWEET_OAUTH_CONSUMER_SECRET\"/;/TWEET_OAUTH_TOKEN_KEY/ s/\:\"\"/\:\"$TWEET_OAUTH_TOKEN_KEY\"/;/TWEET_OAUTH_TOKEN_SECRET/ s/\:\"\"/\:\"$TWEET_OAUTH_TOKEN_SECRET\"/" $IOT_REPO_LOC/marathon/tweet-producer-trump.json

### BEGIN DEMO ###

# Change to demo repo
echo "cd "$IOT_REPO_LOC
cd $IOT_REPO_LOC

echo "Ready to start demo - press [ENTER] when ready"
read

# Start DCOS services:
echo "dcos package install cassandra"
dcos package install cassandra
echo "dcos package install kafka"
dcos package install kafka

echo "Packages Installing - Wait for Kafka to be Healthy then press [ENTER] to configure Brokers"
read

# When Kafka is healthy, add brokers
echo "dcos kafka add 0..2"
dcos kafka add 0..2
echo "dcos kafka update 0..2 --options num.io.threads=16,num.partitions=12"
dcos kafka update 0..2 --options num.io.threads=16,num.partitions=12
echo "dcos kafka start 0..2"
dcos kafka start 0..2
# Show Kafka cluster status
echo "dcos kafka status"
dcos kafka status

echo "Kafka is now fully configured, ready to start Tweet producers - Press [Enter] to Continue"
read

# Add tweet producers
# NOTE: Add twitter API keys first!
echo "dcos marathon app add marathon/tweet-producer-bieber.json"
dcos marathon app add marathon/tweet-producer-bieber.json
echo "dcos marathon app add marathon/tweet-producer-trump.json"
dcos marathon app add marathon/tweet-producer-trump.json

echo "Tweets are now queuing up in Kafka, ready to start Presto - Press [Enter] to Continue when Cassandra is Healthy"
read

# Start Presto:
echo "dcos marathon group add marathon/presto.json"
dcos marathon group add marathon/presto.json

echo "Wait for Presto to launch (check Marathon UI) and then launch to Tweet consumer - Press [Enter] to Continue when Presto has launched"
read

# Last, run tweet consumer
echo "dcos marathon app add marathon/tweet-consumer.json"
dcos marathon app add marathon/tweet-consumer.json

echo "Tweets are now being consumed by Spark and are available via SQL on Cassandra using Presto - Press [Enter] to Continue"
read

cat << EOF



SQL interface is available from the command line on the cluster.  Here are the commands you can run:

ssh core@`echo $DCOS_MASTER_IP` -i `echo $SSH_KEY`

# Initialize the presto cli
docker run -i -t brndnmtthws/presto-cli --server coordinator-presto.marathon.mesos:12000 --catalog cassandra --schema twitter

-- Count all the tweets
SELECT count(1) FROM tweets;

-- Get a list of recent tweets
SELECT substr(tweet_text, 1, 40) AS tweet_text, batchtime, score FROM tweets ORDER BY batchtime DESC LIMIT 20;

-- Count tweets by score
SELECT count(1) AS tweet_count, score FROM tweets GROUP BY score ORDER BY score;

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

EOF

ssh core@`echo $DCOS_MASTER_IP` -t -i `echo $SSH_KEY` "docker run -i -t brndnmtthws/presto-cli --server coordinator-presto.marathon.mesos:12000 --catalog cassandra --schema twitter"
