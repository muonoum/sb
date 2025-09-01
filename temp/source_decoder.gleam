pub fn decoder() -> Decoder(Source) {
  use dict <- decode.then(decode.dict(decode.string, decode.dynamic))

  case dict.to_list(dict) {
    [#("literal", dynamic)] ->
      kind_decoder(dynamic, literal_decoder(), "literal")

    [#("reference", dynamic)] ->
      kind_decoder(dynamic, reference_decoder(), "reference")

    [#("template", dynamic)] ->
      kind_decoder(dynamic, template_decoder(), "template")

    [#("command", dynamic)] ->
      kind_decoder(dynamic, command_decoder(), "command")

    [#("fetch", dynamic)] -> kind_decoder(dynamic, fetch_decoder(), "fetch")

    _bad -> decode.failure(Literal(value.Null), "source")
  }
}

fn kind_decoder(
  dynamic: Dynamic,
  decoder: Decoder(Source),
  message: String,
) -> Decoder(Source) {
  case decode.run(dynamic, decoder) {
    Error(..) -> decode.failure(Literal(value.Null), message)
    Ok(value) -> decode.success(value)
  }
}

fn literal_decoder() -> Decoder(Source) {
  decode.map(value.decoder(), Literal)
}

fn reference_decoder() -> Decoder(Source) {
  decode.map(decode.string, Reference)
}

fn template_decoder() -> Decoder(Source) {
  decode.map(text.decoder(), Template)
}

fn command_decoder() -> Decoder(Source) {
  decode.map(text.decoder(), Command)
}

fn fetch_decoder() -> Decoder(Source) {
  use uri <- decode.field("url", text.decoder())
  use method <- decode.optional_field("method", http.Get, method_decoder())
  use body <- decode.optional_field("body", None, decode.map(decoder(), Some))
  use headers <- decode.optional_field("headers", [], headers_decoder())
  decode.success(Fetch(method:, uri:, headers:, body:))
}

fn method_decoder() -> Decoder(http.Method) {
  use string <- decode.then(decode.string)

  case http.parse_method(string) {
    Error(Nil) -> decode.failure(http.Get, "method")
    Ok(method) -> decode.success(method)
  }
}

fn headers_decoder() -> Decoder(List(#(String, String))) {
  decode.dict(decode.string, decode.string)
  |> decode.map(dict.to_list)
}
