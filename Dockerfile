FROM mesosphere/spark:1.4.1-hdfs

COPY . /iot-demo
WORKDIR /iot-demo

RUN echo "deb http://dl.bintray.com/sbt/debian /" | tee -a /etc/apt/sources.list.d/sbt.list
RUN apt-get update
RUN apt-get install -y --force-yes sbt

RUN sbt -Dsbt.log.format=false assembly
