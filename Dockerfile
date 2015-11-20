FROM mesosphere/spark:1.4.1-hdfs

# Infrastructure, install sbt
RUN echo "deb http://dl.bintray.com/sbt/debian /" | tee -a /etc/apt/sources.list.d/sbt.list
RUN \
    apt-get update &&\
     apt-get install -y --force-yes sbt &&\
      apt-get clean &&\
       rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Only add build files and resolve dependencies first, so that
# they get cached independently and we do not have to do this for every recompile.
ADD build.sbt /iot-demo/build.sbt
ADD project /iot-demo/project

RUN cd /iot-demo && sbt -Dsbt.log.format=false update

# Build the assembly
COPY twitter /iot-demo/twitter
COPY streaming /iot-demo/streaming
COPY rt-polaritydata /
RUN cd /iot-demo && sbt -Dsbt.log.format=false assembly && cp -v */target/scala-2.10/*.jar .. && rm -rf /iot-demo
