package core

import java.util.Properties
import java.util.concurrent.atomic.AtomicLong

import akka.actor._
import akka.event.Logging
import domain.{Place, Tweet, User}
import org.apache.kafka.clients.producer.{Callback, KafkaProducer, ProducerConfig, ProducerRecord, RecordMetadata}

import scala.concurrent.duration._
import scala.util.Random

object RandomTweet {
  private[this] val serialGen = new AtomicLong()

  def apply(keywords: String): Tweet = {
    val id = Random.nextLong()
    val serial = serialGen.incrementAndGet()
    val text = s"Hello DCOS Demo $serial, $keywords"
    val json =
      s"""
         |{
         |    "created_at": "Mon Sep 28 14:59:10 +0000 2015",
         |    "id": $id,
         |    "id_str": "$id",
         |    "text": "$text",
         |    "truncated": false,
         |    "in_reply_to_status_id": null,
         |    "in_reply_to_status_id_str": null,
         |    "in_reply_to_user_id": null,
         |    "in_reply_to_user_id_str": null,
         |    "in_reply_to_screen_name": null,
         |    "user": {
         |        "id": 123,
         |        "id_str": "123",
         |        "name": "DCOSDemoProducer",
         |        "screen_name": "dcosProducer",
         |        "location": "Hamburg, Germany",
         |        "protected": false,
         |        "verified": false,
         |        "followers_count": 580,
         |        "friends_count": 924,
         |        "listed_count": 52,
         |        "favourites_count": 0,
         |        "statuses_count": 13343,
         |        "created_at": "Thu Apr 16 13:17:13 +0000 2015",
         |        "utc_offset": null,
         |        "time_zone": null,
         |        "geo_enabled": false,
         |        "lang": "en",
         |        "contributors_enabled": false,
         |        "is_translator": false,
         |        "following": null,
         |        "follow_request_sent": null,
         |        "notifications": null
         |    },
         |    "geo": null,
         |    "coordinates": null,
         |    "place": null,
         |    "contributors": null,
         |    "retweet_count": 0,
         |    "favorite_count": 0,
         |    "entities": {
         |        "hashtags": [
         |            {
         |                "text": "dcos",
         |                "indices": [
         |                    35,
         |                    41
         |                ]
         |            }
         |        ],
         |        "trends": [],
         |        "urls": [],
         |        "user_mentions": [],
         |        "symbols": []
         |    },
         |    "favorited": false,
         |    "retweeted": false,
         |    "possibly_sensitive": false,
         |    "filter_level": "low",
         |    "lang": "en",
         |    "timestamp_ms": "1443452350630"
         |}
        """.stripMargin
    Tweet(
      id = id.toString,
      user = User(id = "fake", lang = "en", followersCount = 0),
      text = text,
      place = Some(Place("Germany", "Hamburg")),
      json = json
    )
  }
}


class ProducerActor(keywords: String) extends Actor {
  val log = Logging(context.system, this)

  val kafkaTopic = sys.env("TWEET_PRODUCER_KAFKA_TOPIC")
  var producer: KafkaProducer[String, String] = _

  override def preStart(): Unit = {
    val kafkaBrokers = sys.env("TWEET_PRODUCER_KAFKA_BROKERS")

    val props = new Properties()
    props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, kafkaBrokers)
    props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringSerializer")
    props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringSerializer")

    producer = new KafkaProducer[String, String](props)
  }

  override def postStop(): Unit = {
    producer.close()
  }


  def receive: Receive = {
    case tweet: Tweet =>
      val record = new ProducerRecord[String, String](kafkaTopic, tweet.json)
      producer.send(record, new Callback {
        override def onCompletion(result: RecordMetadata, exception: Exception) {
          if (exception != null) {
            log.warning(s"Failed to sent ${tweet.id}: ${tweet.text}", exception)
          } else {
            log.info(s"Sent tweet ${tweet.id}: ${tweet.text}")
          }
        }
      })
  }
}

