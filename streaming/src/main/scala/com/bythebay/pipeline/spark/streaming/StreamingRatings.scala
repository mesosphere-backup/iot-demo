package com.bythebay.pipeline.spark.streaming

import com.datastax.driver.core.Cluster
import kafka.serializer.StringDecoder
import org.apache.spark.mllib.classification.NaiveBayes
import org.apache.spark.mllib.feature.HashingTF
import org.apache.spark.mllib.regression.LabeledPoint
import org.apache.spark.rdd.RDD
import org.apache.spark.sql.{SQLContext, SaveMode}
import org.apache.spark.streaming.kafka.KafkaUtils
import org.apache.spark.streaming.{Seconds, StreamingContext, Time}
import org.apache.spark.{SparkConf, SparkContext}
import org.slf4j.LoggerFactory
import spray.json.{JsString, JsonParser}

case class Tweet(tweet: String, score: Double, batchtime: Long, tweet_text: String, query: String)

object StreamingRatings {
  def main(args: Array[String]) {
    val cassandraContactPoints = sys.env("TWEET_CONSUMER_CASSANDRA_SEEDS")
    val cassandraKeyspace = sys.env("TWEET_CONSUMER_CASSANDRA_KEYSPACE")

    initializeCassandra(cassandraContactPoints, cassandraKeyspace)

    val log = LoggerFactory.getLogger("main")

    val conf = new SparkConf()
      .set(
        "spark.cassandra.connection.host",
        cassandraContactPoints
      )

    val sc = SparkContext.getOrCreate(conf)

    val htf = new HashingTF(10000)
    val positiveData = sc.textFile("/tweet-corpus/positive.gz")
      .map { text => new LabeledPoint(1, htf.transform(text.toLowerCase.split(" "))) }
    val negativeData = sc.textFile("/tweet-corpus/negative.gz")
      .map { text => new LabeledPoint(0, htf.transform(text.toLowerCase.split(" "))) }
    val training = positiveData.union(negativeData)
    val model = NaiveBayes.train(training, lambda = 1.0, modelType = "bernoulli")

    def createStreamingContext(): StreamingContext = {
      @transient val newSsc = new StreamingContext(sc, Seconds(1))
      log.info(s"Creating new StreamingContext $newSsc")

      newSsc
    }
    val ssc = StreamingContext.getActiveOrCreate(createStreamingContext)

    val sqlContext = SQLContext.getOrCreate(sc)

    val kafkaBrokers = sys.env("TWEET_CONSUMER_KAFKA_BROKERS")
    val kafkaTopics = sys.env("TWEET_CONSUMER_KAFKA_TOPIC").split(",").toSet
    val kafkaParams = Map[String, String]("metadata.broker.list" -> kafkaBrokers)

    val ratingsStream = KafkaUtils.createDirectStream[String, String, StringDecoder, StringDecoder](ssc, kafkaParams, kafkaTopics)

    ratingsStream.foreachRDD {
      import sqlContext.implicits._

      (message: RDD[(String, String)], batchTime: Time) => {
        // convert each RDD from the batch into a DataFrame
        val df = message.map(_._2).map(tweet => {
          val json = JsonParser(tweet).asJsObject
          (json.fields.get("text"), json.fields.get("query")) match {
            case (Some(JsString(text)), Some(JsString(query))) =>
              (tweet, text, new LabeledPoint(0, htf.transform(text.toLowerCase.split(" "))), query)
            case _ => (tweet, "", new LabeledPoint(0, htf.transform("".split(""))), "")
          }
        }).map(t => {
          val tweet = t._1
          val text = t._2
          val point = t._3
          val score = model.predict(point.features)
          val query = t._4
          Tweet(tweet, score, batchTime.milliseconds, text, query)
        }).toDF("tweet", "score", "batchtime", "tweet_text", "query")

        df.write.format("org.apache.spark.sql.cassandra")
          .mode(SaveMode.Append)
          .options(Map("keyspace" -> cassandraKeyspace, "table" -> "tweets"))
          .save()
      }
    }

    ssc.start()
    ssc.awaitTermination()
  }

  def initializeCassandra(cassandraContactPoints: String, cassandraKeyspace: String) {
    // Initialize the C* keyspace
    val cluster = Cluster.builder()
      .addContactPoints(cassandraContactPoints)
      .build()
    val session = cluster.connect()
    session.execute(s"CREATE KEYSPACE IF NOT EXISTS $cassandraKeyspace WITH REPLICATION = { 'class': 'SimpleStrategy', 'replication_factor':1}")
    session.execute(s"USE $cassandraKeyspace")
    session.execute("CREATE TABLE IF NOT EXISTS tweets (tweet text, score double, batchTime bigint, tweet_text text, query text, PRIMARY KEY(tweet))")
    session.close()
  }
}
