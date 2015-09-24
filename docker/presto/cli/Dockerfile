FROM java:8-jre

RUN apt-get update
RUN apt-get install -yf less

ADD https://repo1.maven.org/maven2/com/facebook/presto/presto-cli/0.118/presto-cli-0.118-executable.jar /usr/local/bin/presto
RUN chmod +x /usr/local/bin/presto

ENTRYPOINT ["/usr/local/bin/presto"]
