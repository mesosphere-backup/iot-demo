#!/bin/bash

#
# Will use docker to build the necessary jar, then extract the jar and add it to
# a clean image which only contains Java.
#

set -e

TAG=${1:latest}

echo "========== BUILDING BASE IMAGE ========="
BASE_ID="pkolloch/tweet-producer-base"
docker build -t "$BASE_ID" .

echo "========== PREPARE PRODUCTION CONTAINER ========="
mkdir -p twitter/target/docker
cp Dockerfile.tweet-producer twitter/target/docker/Dockerfile
cd twitter/target/docker
docker run --rm=true "$BASE_ID" cat /twitter-assembly-1.0.jar >twitter-assembly-1.0.jar

echo "========== BUILD PRODUCTION CONTAINER ========="
pwd
ID="pkolloch/tweet-producer:$TAG"
docker build -t "$ID" .
docker push "$ID"