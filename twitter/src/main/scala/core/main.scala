package core

import akka.actor.{ActorSystem, Props}
import org.apache.log4j.BasicConfigurator

object Main extends App {
  BasicConfigurator.configure()

  println("args: " + args)

  val query = args.mkString(" ")
  if (query.trim.isEmpty) {
    println("No query was given!!")
    sys.exit(1)
  }

  println(s"Running with query: $query")

  val system = ActorSystem()
  val producer = system.actorOf(Props(new ProducerActor(query)))
  val stream = system.actorOf(Props(
    new TweetStreamerActor(TweetStreamerActor.twitterUri, producer, query) with OAuthTwitterAuthorization))

  stream ! "filter"
}
