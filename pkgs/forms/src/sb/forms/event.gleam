import gleam/dynamic/decode.{type Decoder}

pub type Event {
  Failed
  Requested
  Started
  Succeded
}

pub fn decoder() -> Decoder(Event) {
  use string <- decode.then(decode.string)

  case string {
    "failed" -> decode.success(Failed)
    "requested" -> decode.success(Requested)
    "started" -> decode.success(Started)
    "succeeded" -> decode.success(Succeded)
    _else -> decode.failure(Failed, "event")
  }
}
