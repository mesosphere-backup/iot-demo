#!/bin/bash

. env.sh

docker run -i -t \
    -e TWEET_OAUTH_CONSUMER_KEY="$TWEET_OAUTH_CONSUMER_KEY" \
    -e TWEET_OAUTH_CONSUMER_SECRET="$TWEET_OAUTH_CONSUMER_SECRET" \
    -e TWEET_OAUTH_TOKEN_KEY="$TWEET_OAUTH_TOKEN_KEY" \
    -e TWEET_OAUTH_TOKEN_SECRET="$TWEET_OAUTH_TOKEN_SECRET" \
    -e TWEET_PRODUCER_KAFKA_BROKERS="$TWEET_PRODUCER_KAFKA_BROKERS" \
    -e TWEET_PRODUCER_KAFKA_TOPIC="$TWEET_PRODUCER_KAFKA_TOPIC" \
    pkolloch/twitter-stream \
    java -Xmx2000m -Dakka.loglevel=DEBUG -Dakka.actor.debug.receive=true -Dakka.actor.debug.autoreceive=true \
    -Dakka.actor.debug.lifecycle=true -jar /twitter-assembly-1.0.jar jobs
