FROM java:8-jre

RUN apt-get update
RUN apt-get install -yf python

ADD https://downloads.mesosphere.io/presto/presto-server-0.118.tar.gz presto-server-0.118.tar.gz
RUN tar xf presto-server-0.118.tar.gz
RUN rm presto-server-0.118.tar.gz

WORKDIR presto-server-0.118
