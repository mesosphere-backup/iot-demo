FROM java:8-jre

ADD https://repo1.maven.org/maven2/com/facebook/presto/presto-cli/0.118/presto-cli-0.118-executable.jar /usr/local/bin/presto

RUN apt-get update && \
  apt-get install -yf less && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
  chmod +x /usr/local/bin/presto

ENTRYPOINT ["/usr/local/bin/presto"]
