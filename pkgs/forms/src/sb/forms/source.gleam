import gleam/bytes_tree.{type BytesTree}
import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri
import sb/extra
import sb/extra/report.{type Report}
import sb/extra/state
import sb/forms/custom
import sb/forms/decoder
import sb/forms/error.{type Error}
import sb/forms/handlers.{type Handlers}
import sb/forms/props.{type Props}
import sb/forms/scope.{type Scope}
import sb/forms/text.{type Text}
import sb/forms/value.{type Value}
import sb/forms/zero

const literal_keys = ["literal"]

const reference_keys = ["reference"]

const template_keys = ["template"]

const command_keys = ["command"]

const fetch_keys = ["method", "url", "headers", "body"]

pub type Source {
  Loading(fn() -> Result(Source, Report(Error)))
  Literal(Value)
  Reference(String)
  Template(Text)
  Command(Text)

  Fetch(
    method: http.Method,
    uri: Text,
    headers: List(http.Header),
    body: Option(Source),
  )
}

pub fn refs(source: Source) -> List(String) {
  case source {
    Literal(..) -> []
    Loading(..) -> []
    Reference(id) -> [id]
    Template(text) -> text.refs(text)
    Command(text) -> text.refs(text)

    Fetch(uri:, body:, ..) ->
      list.unique(list.append(
        text.refs(uri),
        option.map(body, refs)
          |> option.unwrap([]),
      ))
  }
}

pub fn evaluate(
  source: Source,
  scope: Scope,
  search search: Option(String),
  handlers handlers: Handlers,
) -> Result(Source, Report(Error)) {
  case source {
    Loading(load) -> load()
    Literal(value) -> Ok(Literal(value))

    Reference(id) ->
      case scope.value(scope, id) {
        Ok(value) -> Ok(Literal(value))
        Error(Nil) -> Ok(Reference(id))
      }

    Template(text) ->
      case text.evaluate(text, scope, placeholder: None) {
        Error(report) -> Error(report)
        Ok(None) -> Ok(Template(text))
        Ok(Some(string)) -> Ok(Literal(value.String(string)))
      }

    Command(text) ->
      case text.evaluate(text, scope, placeholder: search) {
        Error(report) -> Error(report)
        Ok(None) -> Ok(Command(text))
        Ok(Some(_string)) -> todo as "evaluate command"
      }

    Fetch(method:, uri:, headers:, body: None) -> {
      let placeholder = option.map(search, uri.percent_encode)

      case text.evaluate(uri, scope, placeholder:) {
        Error(report) -> Error(report)
        Ok(None) -> Ok(Fetch(method, uri, headers, body: None))

        Ok(Some(string)) -> {
          use request <- result.map(build_request(method, string, headers))

          use <- Loading
          send_request(request, value.decoder(), handlers.http)
          |> result.map(Literal)
        }
      }
    }

    Fetch(method:, uri:, headers:, body: Some(body)) -> {
      let placeholder = option.map(search, uri.percent_encode)

      case text.evaluate(uri, scope, placeholder:) {
        Error(report) -> Error(report)
        Ok(None) -> Ok(Fetch(method:, uri:, headers:, body: Some(body)))

        Ok(Some(string)) ->
          case evaluate(body, scope, search, handlers) {
            Error(report) -> Error(report)

            Ok(Literal(value)) -> {
              use request <- result.map(
                build_request(method, string, headers)
                |> result.map(set_request_body(_, value)),
              )

              use <- Loading
              send_request(request, value.decoder(), handlers.http)
              |> result.map(Literal)
            }

            Ok(source) -> Ok(Fetch(method:, uri:, headers:, body: Some(source)))
          }
      }
    }
  }
}

fn build_request(
  method: http.Method,
  uri: String,
  headers: List(http.Header),
) -> Result(Request(_), Report(Error)) {
  use request <- result.map({
    uri.parse(uri)
    |> result.try(request.from_uri)
    |> report.replace_error(error.BadProperty("url"))
  })

  let request =
    request.set_method(request, method)
    |> request.set_header("accept", "application/json")
    |> request.set_body(None)

  use request, #(key, value) <- list.fold(headers, request)
  request.set_header(request, key, value)
}

fn set_request_body(
  request: Request(v),
  value: Value,
) -> Request(Option(BytesTree)) {
  request
  |> request.set_header("content-type", "application/json")
  |> request.set_body(Some(
    value.to_json(value)
    |> json.to_string_tree
    |> bytes_tree.from_string_tree,
  ))
}

fn send_request(
  request: Request(v),
  decoder: Decoder(Value),
  handler: fn(Request(v)) -> Result(Response(BitArray), Report(Error)),
) -> Result(Value, Report(Error)) {
  use response <- result.try(handler(request))
  parse_json(response.body, decoder)
}

fn parse_json(bits: BitArray, decoder: Decoder(v)) -> Result(v, Report(Error)) {
  json.parse_bits(bits, decoder)
  |> report.map_error(error.JsonError)
}

pub fn decoder(sources: custom.Sources) -> Props(Source) {
  use dict <- props.get_dict

  case dict.to_list(dict) {
    [#("literal", dynamic)] -> state.from_result(decode_literal(dynamic))
    [#("reference", dynamic)] -> state.from_result(decode_reference(dynamic))
    [#("template", dynamic)] -> state.from_result(decode_template(dynamic))
    [#("command", dynamic)] -> state.from_result(decode_command(dynamic))
    [#("fetch", dynamic)] -> state.from_result(decode_fetch(dynamic, sources))
    [#("kind", _dynamic)] -> kind_decoder(sources)
    [#(name, _)] -> state.from_result(report.error(error.UnknownKind(name)))
    // TODO: custom sources
    _else -> kind_decoder(sources)
  }
}

fn kind_decoder(sources: custom.Sources) -> Props(Source) {
  use kind <- props.get("kind", decoder.from(decode.string))

  use <- result.lazy_unwrap({
    use dict <- result.map(custom.get_source(sources, echo kind) |> echo)
    use <- state.do(props.merge(dict))
    kind_decoder(sources)
  })

  let context = report.context(_, error.BadKind(kind))
  use <- extra.return(state.map_error(_, context))

  case kind {
    "literal" -> state.do(props.drop(["kind"]), literal_decoder)
    "reference" -> state.do(props.drop(["kind"]), reference_decoder)
    "template" -> state.do(props.drop(["kind"]), template_decoder)
    "command" -> state.do(props.drop(["kind"]), command_decoder)

    "fetch" -> {
      use <- state.do(props.drop(["kind"]))
      fetch_decoder(sources)
    }

    name -> state.fail(report.new(error.UnknownKind(name)))
  }
}

fn decode_literal(dynamic: Dynamic) -> Result(Source, Report(Error)) {
  decoder.run(dynamic, value.decoder())
  |> report.error_context(error.BadKind("literal"))
  |> result.map(Literal)
}

fn literal_decoder() -> Props(Source) {
  use <- state.do(props.check_keys(literal_keys))
  use value <- props.get("literal", decoder.from(value.decoder()))
  state.succeed(Literal(value))
}

fn decode_reference(dynamic: Dynamic) -> Result(Source, Report(Error)) {
  text.id_decoder(dynamic)
  |> report.error_context(error.BadKind("reference"))
  |> result.map(Reference)
}

fn reference_decoder() -> Props(Source) {
  use <- state.do(props.check_keys(reference_keys))
  use id <- props.get("reference", text.id_decoder)
  state.succeed(Reference(id))
}

fn decode_template(dynamic: Dynamic) -> Result(Source, Report(Error)) {
  text.decoder(dynamic)
  |> report.error_context(error.BadKind("template"))
  |> result.map(Template)
}

fn template_decoder() -> Props(Source) {
  use <- state.do(props.check_keys(template_keys))
  use text <- props.get("template", text.decoder)
  state.succeed(Template(text))
}

fn decode_command(dynamic: Dynamic) -> Result(Source, Report(Error)) {
  text.decoder(dynamic)
  |> report.error_context(error.BadKind("command"))
  |> result.map(Command)
}

fn command_decoder() -> Props(Source) {
  use <- state.do(props.check_keys(command_keys))
  use command <- props.get("command", text.decoder)
  state.succeed(Command(command))
}

fn decode_fetch(
  dynamic: Dynamic,
  sources: custom.Sources,
) -> Result(Source, Report(Error)) {
  use <- result.lazy_or({
    use uri <- result.map(text.decoder(dynamic))
    Fetch(method: http.Get, uri:, headers: [], body: None)
  })

  props.decode(dynamic, fetch_decoder(sources))
  |> report.error_context(error.BadKind("fetch"))
}

fn fetch_decoder(sources: custom.Sources) -> Props(Source) {
  use <- state.do(props.check_keys(fetch_keys))
  use uri <- props.get("url", text.decoder)
  use body <- props.try("body", zero.option(props.decode(_, decoder(sources))))

  use method <- props.try("method", {
    use dynamic <- zero.new(http.Get)
    use string <- result.try(decoder.run(dynamic, decode.string))
    http.parse_method(string.uppercase(string))
    |> report.replace_error(error.BadProperty("method"))
  })

  use headers <- props.try("headers", {
    use dynamic <- zero.list
    decoder.run(dynamic, decode.dict(decode.string, decode.string))
    |> report.error_context(error.BadProperty("headers"))
    |> result.map(dict.to_list)
  })

  state.succeed(Fetch(method:, uri:, headers:, body:))
}
