package core

import java.util.Properties
import akka.event.Logging
import org.apache.kafka.clients.producer.{KafkaProducer, ProducerConfig}
import akka.actor._
import org.apache.kafka.clients.producer.{ProducerRecord,Callback,RecordMetadata}
import domain.Tweet

class ProducerActor extends Actor {
  val log = Logging(context.system, this)

  val kafkaBrokers = sys.env("TWEET_PRODUCER_KAFKA_BROKERS")
  val kafkaTopic = sys.env("TWEET_PRODUCER_KAFKA_TOPIC")

  val props = new Properties()
  props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, kafkaBrokers)
  props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringSerializer")
  props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.StringSerializer")

  val producer = new KafkaProducer[String, String](props)

  def receive: Receive = {
    case tweet: Tweet =>
      val record = new ProducerRecord[String,String](kafkaTopic, tweet.json)
      producer.send(record, new Callback {
        override def onCompletion(result: RecordMetadata, exception: Exception) {
          if (exception != null) {
            log.warning("Failed to send record", exception)
          }
        }
      })
  }
}
