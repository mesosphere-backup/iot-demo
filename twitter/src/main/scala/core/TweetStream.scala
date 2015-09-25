package core

import org.slf4j.LoggerFactory
import spray.httpx.unmarshalling.{DeserializationError, MalformedContent, Unmarshaller, Deserialized}
import spray.http._
import spray.json._
import spray.client.pipelining._
import akka.actor.{ActorLogging, ActorRef, Actor}
import spray.http.HttpRequest
import domain.{Place, User, Tweet}
import scala.util.Try
import spray.can.Http
import akka.io.IO
import scala.concurrent.duration._

trait TwitterAuthorization {
  def authorize: HttpRequest => HttpRequest
}

trait OAuthTwitterAuthorization extends TwitterAuthorization {
  import OAuth._

  val consumer = Consumer(
    sys.env("TWEET_OAUTH_CONSUMER_KEY"),
    sys.env("TWEET_OAUTH_CONSUMER_SECRET")
  )
  val token = Token(
    sys.env("TWEET_OAUTH_TOKEN_KEY"),
    sys.env("TWEET_OAUTH_TOKEN_SECRET")
  )

  val authorize: (HttpRequest) => HttpRequest = oAuthAuthorizer(consumer, token)
}

trait TweetMarshaller {

  object TweetUnmarshaller {

    def mkUser(user: JsObject): Deserialized[User] = {
      (user.fields("id_str"), user.fields("lang"), user.fields("followers_count")) match {
        case (JsString(id), JsString(lang), JsNumber(followers)) => Right(User(id, lang, followers.toInt))
        case (JsString(id), _, _)                                => Right(User(id, "", 0))
        case _                                                   => Left(MalformedContent("bad user"))
      }
    }

    def mkPlace(place: JsValue): Deserialized[Option[Place]] = place match {
      case JsObject(fields) =>
        (fields.get("country"), fields.get("name")) match {
          case (Some(JsString(country)), Some(JsString(name))) => Right(Some(Place(country, name)))
          case _                                               => Left(MalformedContent("bad place"))
        }
      case JsNull => Right(None)
      case _ => Left(MalformedContent("bad tweet"))
    }

    def apply(entityString: String): Deserialized[Tweet] = {
      Try {
        val json = JsonParser(entityString).asJsObject
        (json.fields.get("id_str"), json.fields.get("text"), json.fields.get("place"), json.fields.get("user")) match {
          case (Some(JsString(id)), Some(JsString(text)), Some(place), Some(user: JsObject)) =>
            val x = mkUser(user).fold(x => Left(x), { user =>
              mkPlace(place).fold(x => Left(x), { place =>
                Right(Tweet(id, user, text, place, entityString))
              })
            })
            x
          case _ => Left(MalformedContent("bad tweet"))
        }
      }
    }.getOrElse(Left(MalformedContent("bad json")))
  }
}

/**
 * Receives a stream of string chunks and exposes
 * all received segments that are delimited by newlines as an iterator.
 */
class ChunkCombiner {
  private[this] var buffer: String = ""

  def feed(chunk: String): Unit = {
    buffer += chunk
  }

  def iterator: Iterator[String] = {
    new Iterator[String] {
      override def hasNext: Boolean = buffer.indexOf('\n') >= 0

      override def next(): String = {
        val index = buffer.indexOf('\n')
        val ret = buffer.substring(0, index)
        buffer = buffer.substring(index+1)
        ret
      }
    }
  }
}

object TweetStreamerActor {
  val twitterUri = Uri("https://stream.twitter.com/1.1/statuses/filter.json")
}

class TweetStreamerActor(uri: Uri, producer: ActorRef, query: String) extends Actor with TweetMarshaller with ActorLogging {
  this: TwitterAuthorization =>
  val io = IO(Http)(context.system)
  import scala.concurrent.ExecutionContext.Implicits.global

  var chunkCombiner = new ChunkCombiner()

  def receive: Receive = {
    case "filter" =>
      log.info(s"Sending query request to $uri")
      val body = HttpEntity(ContentType(MediaTypes.`application/x-www-form-urlencoded`), s"track=$query")
      val rq = HttpRequest(HttpMethods.POST, uri = uri, entity = body) ~> authorize
      sendTo(io).withResponsesReceivedBy(self)(rq)
    case ChunkedResponseStart(_) =>
      chunkCombiner = new ChunkCombiner()
    case MessageChunk(entity, _) =>
      val entityString = entity.asString(HttpCharsets.`UTF-8`)
      chunkCombiner.feed(entityString)
      chunkCombiner.iterator.foreach { tweetString =>
        TweetUnmarshaller(tweetString).fold(
          { (error: DeserializationError) =>
            log.error("error while parsing tweet {}: {}", error, new String(entity.toByteArray))
          },
          { message =>
            log.info("received tweet: {}", message)
            producer ! message
          }
        )
      }
    case _ =>
      context.system.scheduler.scheduleOnce(5 seconds) {
        self ! "filter"
      }
  }
}
