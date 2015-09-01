package core

import java.net.URLEncoder

import akka.actor.{Props, ActorSystem}

object Main extends App {
  val query = args.mkString(" ")
  println(s"Running with query: $query")

  val system = ActorSystem()
  val producer = system.actorOf(Props(new ProducerActor))
  val stream = system.actorOf(Props(
    new TweetStreamerActor(TweetStreamerActor.twitterUri, producer, query)))

  stream ! "filter"
}
