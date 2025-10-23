import gleam/dynamic/decode.{type Decoder}
import gleam/list
import gleam/string
import gleam/uri.{type Uri}
import sb/extra/report
import sb/extra/state
import sb/forms/decoder
import sb/forms/error
import sb/forms/props
import sb/forms/zero

// TODO
const default_timeout = 10_000

// TODO: Kanskje command proxy bør være en egen custom type
pub type Proxy {
  Internal
  External(Uri)
}

pub type Command {
  Command(
    executable: String,
    arguments: List(String),
    proxy: Proxy,
    timeout: Int,
  )
}

pub fn decoder() -> props.Try(#(String, Command)) {
  use id <- props.get("id", decoder.from(decode.string))
  use command <- props.get("command", decoder.from(decode.string))
  use proxy <- props.get("proxy", decoder.from(proxy_decoder()))

  use timeout <- props.try("timeout", {
    zero.new(default_timeout, decoder.from(decode.int))
  })

  let parts = {
    use string <- list.filter(string.split(command, " "))
    string.trim(string) != ""
  }

  case parts {
    [] -> state.error(report.new(error.Todo("empty command")))

    [executable, ..arguments] ->
      state.ok(#(id, Command(executable:, arguments:, proxy:, timeout:)))
  }
}

// fn duration_decoder() -> Decoder(Duration) {
//   use string <- decode.then(decode.string)

//   case parser.parse_string(string, duration_extra.parser()) {
//     Error(_error) -> decode.failure(duration.seconds(10), "duration")
//     Ok(duration) -> decode.success(duration)
//   }
// }

fn proxy_decoder() -> Decoder(Proxy) {
  use uri_string <- decode.then(decode.string)

  case uri_string {
    "internal" -> decode.success(Internal)

    _else ->
      case uri.parse(uri_string) {
        Error(Nil) -> decode.failure(Internal, "uri")
        Ok(uri) -> decode.success(External(uri))
      }
  }
}
