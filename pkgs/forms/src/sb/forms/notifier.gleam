import gleam/dynamic/decode
import sb/extra/report
import sb/extra/state
import sb/forms/decoder
import sb/forms/error
import sb/forms/props

pub type Notifier {
  Slack
}

pub fn decoder() -> props.Try(#(String, Notifier)) {
  use id <- props.get("id", decoder.from(decode.string))
  use kind <- props.get("kind", decoder.from(decode.string))

  case kind {
    "slack" -> state.ok(#(id, Slack))
    unknown -> state.error(report.new(error.UnknownKind(unknown)))
  }
}
