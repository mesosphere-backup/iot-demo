package core

import akka.actor.{ActorSystem, Props}
import org.apache.log4j.BasicConfigurator

object Main extends App {
  BasicConfigurator.configure()

  val query = args.mkString(" ")
  println(s"Running with query: $query")

  val system = ActorSystem()
  val producer = system.actorOf(Props(new ProducerActor))
  val stream = system.actorOf(Props(
    new TweetStreamerActor(TweetStreamerActor.twitterUri, producer, query) with OAuthTwitterAuthorization))

  stream ! "filter"
}
