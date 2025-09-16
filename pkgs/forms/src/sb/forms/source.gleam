import gleam/bytes_tree.{type BytesTree}
import gleam/dict
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set.{type Set}
import gleam/string
import gleam/uri
import sb/extra/function.{return}
import sb/extra/report.{type Report}
import sb/extra/state_eval as state
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

pub fn is_loading(source: Source) -> Bool {
  case source {
    Loading(..) -> True
    Fetch(body: option.Some(body), ..) -> is_loading(body)
    Literal(..) | Reference(..) | Template(..) | Command(..) | Fetch(..) ->
      False
  }
}

pub fn refs(source: Source) -> List(String) {
  case source {
    Literal(..) | Loading(..) -> []
    Reference(id) -> [id]
    Template(text) | Command(text) -> text.refs(text)

    Fetch(uri:, body:, ..) ->
      list.unique(list.append(
        text.refs(uri),
        option.map(body, refs)
          |> option.unwrap([]),
      ))
  }
}

pub fn value(source: Source) -> Result(Value, Nil) {
  case source {
    Literal(value) -> Ok(value)
    _else -> Error(Nil)
  }
}

pub fn keys(source: Source) -> List(Value) {
  result.try(value(source), value.keys)
  |> result.unwrap([])
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
        Ok(Some(_string)) -> report.error(error.Todo("evaluate command"))
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

pub fn decoder(sources sources: custom.Sources) -> Props(Source) {
  seen_decoder(set.new(), sources:)
}

fn seen_decoder(
  seen: Set(String),
  sources sources: custom.Sources,
) -> Props(Source) {
  use dict <- props.get_dict

  case dict.to_list(dict) {
    [#("literal", dynamic)] ->
      state.from_result(
        decoder.run(dynamic, value.decoder())
        |> report.error_context(error.BadKind("literal"))
        |> result.map(Literal),
      )

    [#("reference", dynamic)] ->
      state.from_result(
        text.id_decoder(dynamic)
        |> report.error_context(error.BadKind("reference"))
        |> result.map(Reference),
      )

    [#("template", dynamic)] ->
      state.from_result(
        text.decoder(dynamic)
        |> report.error_context(error.BadKind("template"))
        |> result.map(Template),
      )

    [#("command", dynamic)] ->
      state.from_result(
        text.decoder(dynamic)
        |> report.error_context(error.BadKind("command"))
        |> result.map(Command),
      )

    [#("fetch", dynamic)] ->
      state.from_result({
        use <- result.lazy_or({
          use uri <- result.map(text.decoder(dynamic))
          Fetch(method: http.Get, uri:, headers: [], body: None)
        })

        props.decode(dynamic, fetch_decoder(set.new(), sources:))
        |> report.error_context(error.BadKind("fetch"))
      })

    // TODO
    [#("kind", _dynamic)] -> kind_decoder(seen, sources:)
    [#(name, _)] -> props.fail(report.new(error.UnknownKind(name)))
    _else -> kind_decoder(seen, sources:)
  }
}

fn kind_decoder(
  seen: Set(String),
  sources sources: custom.Sources,
) -> Props(Source) {
  use seen, name <- custom.kind_decoder(seen, sources, custom.get_source)
  use <- return(props.error_context(error.BadKind(name)))
  use <- state.do(props.drop(["kind"]))

  case name {
    "literal" -> {
      use <- state.do(props.check_keys(literal_keys))
      use value <- props.get("literal", decoder.from(value.decoder()))
      props.succeed(Literal(value))
    }

    "reference" -> {
      use <- state.do(props.check_keys(reference_keys))
      use id <- props.get("reference", text.id_decoder)
      props.succeed(Reference(id))
    }

    "template" -> {
      use <- state.do(props.check_keys(template_keys))
      use text <- props.get("template", text.decoder)
      props.succeed(Template(text))
    }

    "command" -> {
      use <- state.do(props.check_keys(command_keys))
      use command <- props.get("command", text.decoder)
      props.succeed(Command(command))
    }

    "fetch" -> {
      use <- state.do(props.check_keys(fetch_keys))
      fetch_decoder(seen, sources:)
    }

    unknown -> props.fail(report.new(error.UnknownKind(unknown)))
  }
}

fn fetch_decoder(
  seen: Set(String),
  sources sources: custom.Sources,
) -> Props(Source) {
  use method <- props.try("method", {
    use dynamic <- zero.new(http.Get)
    use string <- result.try(decoder.run(dynamic, decode.string))
    http.parse_method(string.uppercase(string))
    |> report.replace_error(error.BadProperty("method"))
  })

  use uri <- props.get("url", text.decoder)

  use headers <- props.try("headers", {
    use dynamic <- zero.list
    decoder.run(dynamic, decode.dict(decode.string, decode.string))
    |> report.error_context(error.BadProperty("headers"))
    |> result.map(dict.to_list)
  })

  use body <- props.try("body", {
    zero.option(props.decode(_, seen_decoder(seen, sources:)))
  })

  props.succeed(Fetch(method:, uri:, headers:, body:))
}
