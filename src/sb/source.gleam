import gleam/bytes_tree
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/uri
import sb/error.{type Error}
import sb/handlers.{type Handlers}
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

    Fetch(method, uri, headers, body: None) -> {
      let placeholder = option.map(search, uri.percent_encode)

      case text.evaluate(uri, scope, placeholder:) {
        Error(report) -> Error(report)
        Ok(None) -> Ok(Fetch(method, uri, headers, body: None))

        Ok(Some(string)) -> {
          use request <- result.map(build_request(method, string, headers))

          use <- Loading
          send_request(request, handlers.http)
          |> result.map(Literal)
        }
      }
    }

    Fetch(method, uri, headers, Some(body)) -> {
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
              send_request(request, handlers.http)
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

pub fn set_request_body(request: Request(_), value: Value) -> Request(_) {
  request
  |> request.set_header("content-type", "application/json")
  |> request.set_body(Some(
    value.to_json(value)
    |> json.to_string_tree
    |> bytes_tree.from_string_tree,
  ))
}

pub fn send_request(
  request: Request(_),
  handler: fn(Request(_)) -> Result(Response(_), Report(Error)),
) -> Result(Value, Report(Error)) {
  use response <- result.try(handler(request))
  parse_json(response.body, value.decoder())
}

pub fn parse_json(
  bits: BitArray,
  decoder: Decoder(a),
) -> Result(a, Report(Error)) {
  json.parse_bits(bits, decoder)
  |> report.map_error(error.JsonError)
}
