FROM java:8-jre

ADD https://downloads.mesosphere.com/presto/presto-server-0.144.1-1.tar.gz presto-server-0.144.1.tar.gz

RUN apt-get update && \
  apt-get install -yf python && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
  tar xf presto-server-0.144.1.tar.gz && \
  rm presto-server-0.144.1.tar.gz

WORKDIR presto-server-0.144.1
