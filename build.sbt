val globalSettings = Seq(
  version := "1.0",
  scalaVersion := "2.10.5"
)

lazy val streaming = (project in file("streaming"))
                       .settings(name := "streaming")
                       .settings(globalSettings:_*)
                       .settings(libraryDependencies ++= streamingDeps)

lazy val twitter = (project in file("twitter"))
  .settings(name := "twitter")
  .settings(globalSettings:_*)
  .settings(libraryDependencies ++= twitterDeps)

val akkaVersion = "2.3.11"
val sparkVersion = "1.6.1"
val sparkCassandraConnectorVersion = "1.6.0-M2"
val kafkaVersion = "0.8.2.1"
val scalaTestVersion = "2.2.4"
val sprayVersion = "1.3.3"

lazy val streamingDeps = Seq(
  "com.datastax.spark" % "spark-cassandra-connector_2.10" % sparkCassandraConnectorVersion % "provided",
  "org.apache.spark"  %% "spark-sql"             % sparkVersion % "provided",
  "org.apache.spark"  %% "spark-streaming"       % sparkVersion % "provided",
  "org.apache.spark"  %% "spark-streaming-kafka" % sparkVersion % "provided",
  "org.apache.spark"  %% "spark-mllib"           % sparkVersion % "provided",
  "io.spray"          %% "spray-client"          % sprayVersion,
  "io.spray"          %% "spray-json"            % "1.3.2",
  "com.databricks"    %% "spark-csv"             % "1.2.0"
)

lazy val twitterDeps = Seq(
//  "ch.qos.logback"      %  "logback-classic"      % "1.0.7",
  "com.typesafe"        %% "scalalogging-slf4j"   % "1.0.1",
  "com.typesafe.akka"      %% "akka-actor"            % akkaVersion,
  "com.typesafe.akka"      %% "akka-slf4j"            % akkaVersion,
  "io.spray"               %% "spray-can"             % sprayVersion,
  "io.spray"               %% "spray-client"          % sprayVersion,
  "io.spray"               %% "spray-routing"         % sprayVersion,
  "io.spray"               %% "spray-json"            % "1.3.2",
  "org.specs2"             %% "specs2"                % "2.2.2"        % "test",
  "io.spray"               %% "spray-testkit"         % sprayVersion   % "test",
  "com.typesafe.akka"      %% "akka-testkit"          % akkaVersion    % "test",
  "org.apache.kafka" % "kafka_2.10" % kafkaVersion
    exclude("javax.jms", "jms")
    exclude("com.sun.jdmk", "jmxtools")
    exclude("com.sun.jmx", "jmxri")
)
