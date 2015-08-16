package core

import akka.actor.{Props, ActorSystem}

object Main extends App {
  val query = args.mkString(" ")
  println(s"Running with query: $query")

  val system = ActorSystem()
  val sentiment = system.actorOf(Props(new ProducerActor))
  val stream = system.actorOf(Props(
    new TweetStreamerActor(TweetStreamerActor.twitterUri, sentiment) with OAuthTwitterAuthorization))

  stream ! query
}
