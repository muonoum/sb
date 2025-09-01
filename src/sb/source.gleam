import extra
import extra/state
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
import sb/decoder
import sb/error.{type Error}
import sb/handlers.{type Handlers}
import sb/props.{type Props}
import sb/report.{type Report}
import sb/scope.{type Scope}
import sb/text.{type Text}
import sb/value.{type Value}

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

pub fn build_request(
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

pub fn set_request_body(
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

pub fn send_request(
  request: Request(v),
  decoder: Decoder(Value),
  handler: fn(Request(v)) -> Result(Response(BitArray), Report(Error)),
) -> Result(Value, Report(Error)) {
  use response <- result.try(handler(request))
  parse_json(response.body, decoder)
}

pub fn parse_json(
  bits: BitArray,
  decoder: Decoder(v),
) -> Result(v, Report(Error)) {
  json.parse_bits(bits, decoder)
  |> report.map_error(error.JsonError)
}

pub fn decoder() -> Props(Source) {
  use dict <- state.with(state.get())
  use <- extra.return(state.from_result)

  case dict.to_list(dict) {
    [#("literal", dynamic)] -> literal_decoder(dynamic)
    [#("reference", dynamic)] -> reference_decoder(dynamic)
    [#("template", dynamic)] -> template_decoder(dynamic)
    [#("command", dynamic)] -> command_decoder(dynamic)
    [#("fetch", dynamic)] -> fetch_decoder(dynamic)
    [#(name, _)] -> report.error(error.UnknownKind(name))
    _bad -> report.error(error.BadSource)
  }
}

fn literal_decoder(dynamic: Dynamic) -> Result(Source, Report(Error)) {
  use <- extra.return(report.error_context(_, error.BadKind("literal")))
  result.map(decoder.run(dynamic, value.decoder()), Literal)
}

fn reference_decoder(dynamic: Dynamic) -> Result(Source, Report(Error)) {
  use <- extra.return(report.error_context(_, error.BadKind("reference")))
  result.map(decoder.run(dynamic, decode.string), Reference)
}

fn template_decoder(dynamic: Dynamic) -> Result(Source, Report(Error)) {
  use <- extra.return(report.error_context(_, error.BadKind("template")))
  result.map(text.decoder(dynamic), Template)
}

fn command_decoder(_dynamic: Dynamic) -> Result(Source, Report(Error)) {
  use <- extra.return(report.error_context(_, error.BadKind("command")))
  todo as "decode command"
}

fn fetch_decoder(dynamic: Dynamic) -> Result(Source, Report(Error)) {
  use <- extra.return(report.error_context(_, error.BadKind("fetch")))

  use <- result.lazy_or(
    text.decoder(dynamic)
    |> result.map(Fetch(
      method: http.Get,
      uri: _,
      headers: [],
      body: option.None,
    )),
  )

  use <- extra.return(props.decode(dynamic, _))

  use uri <- props.field("url", text.decoder)

  use body <- props.default_field("body", Ok(None), {
    props.decode(_, state.map(decoder(), Some))
  })

  use method <- props.default_field("method", Ok(http.Get), fn(dynamic) {
    decoder.run(dynamic, decode.string)
    |> result.try(fn(string) {
      http.parse_method(string.uppercase(string))
      |> report.replace_error(error.BadProperty("method"))
    })
  })

  use headers <- props.default_field("headers", Ok([]), fn(dynamic) {
    decoder.run(dynamic, decode.dict(decode.string, decode.string))
    |> report.error_context(error.BadProperty("headers"))
    |> result.map(dict.to_list)
  })

  state.succeed(Fetch(method:, uri:, headers:, body:))
}
