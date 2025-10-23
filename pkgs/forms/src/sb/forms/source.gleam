import gleam/bool
import gleam/bytes_tree.{type BytesTree}
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/response.{type Response}
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set.{type Set}
import gleam/string
import gleam/uri
import sb/extra/dynamic as dynamic_extra
import sb/extra/function.{return}
import sb/extra/report.{type Report}
import sb/extra/request_builder.{type RequestBuilder}
import sb/extra/reset.{type Reset}
import sb/extra/state
import sb/extra/string as string_extra
import sb/forms/custom
import sb/forms/decoder
import sb/forms/error.{type Error}
import sb/forms/handlers.{type Handlers}
import sb/forms/props
import sb/forms/scope.{type Scope}
import sb/forms/text.{type Text}
import sb/forms/value.{type Value}
import sb/forms/zero.{type Zero}

// TODO
const default_timeout = 10_000

pub const builtin = ["literal", "reference", "template", "command", "fetch"]

const command_keys = ["command", "stdin"]

const fetch_keys = ["method", "url", "headers", "body"]

pub type Source {
  Loading(fn() -> Result(Source, Report(Error)))

  Literal(Value)
  Reference(String)
  Template(Text)
  Command(command: Text, stdin: Option(Source))

  Fetch(
    method: http.Method,
    uri: Text,
    headers: List(http.Header),
    body: Option(Source),
    timeout: Int,
  )
}

pub type Resetable =
  Reset(Result(Source, Report(Error)))

pub fn is_loading(source: Source) -> Bool {
  case source {
    Loading(..) -> True

    Fetch(body: Some(body), ..) -> is_loading(body)
    Command(stdin: Some(stdin), ..) -> is_loading(stdin)

    Literal(..) -> False
    Reference(..) -> False
    Template(..) -> False
    Command(..) -> False
    Fetch(..) -> False
  }
}

pub fn refs(source: Source) -> List(String) {
  case source {
    Loading(..) -> []
    Literal(..) -> []

    Reference(id) -> [id]
    Template(text) | Command(command: text, ..) -> text.refs(text)

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

pub fn has_placeholder(source: Source) -> Bool {
  case source {
    Loading(..) -> False
    Literal(..) -> False
    Reference(..) -> False

    Command(command: text, ..) | Template(text) | Fetch(uri: text, ..) ->
      text.has_placeholder(text)
  }
}

pub fn initial_placeholder(source: Resetable) -> Bool {
  reset.unwrap(reset.initial(source))
  |> result.map(has_placeholder)
  |> result.unwrap(False)
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
        Some(Ok(value)) -> Ok(Literal(value))
        Some(Error(_)) | None -> Ok(Reference(id))
      }

    Template(text) ->
      case text.evaluate(text, scope, placeholder: None) {
        Error(report) -> Error(report)
        Ok(None) -> Ok(Template(text))
        Ok(Some(string)) -> Ok(Literal(value.String(string)))
      }

    Command(command:, stdin: None) -> {
      case text.evaluate(command, scope, placeholder: search) {
        Error(report) -> Error(report)
        Ok(None) -> Ok(Command(command:, stdin: None))

        Ok(Some(command_string)) ->
          Ok({
            let arguments = string_extra.words(command_string)

            use <- Loading
            use string <- result.try(handlers.command(arguments, None))

            dynamic.string(string)
            |> decoder.run(value.decoder())
            |> result.map(Literal)
          })
      }
    }

    Command(command:, stdin: Some(stdin)) ->
      case text.evaluate(command, scope, placeholder: search) {
        Error(report) -> Error(report)
        Ok(None) -> Ok(Command(command:, stdin: Some(stdin)))

        Ok(Some(command_string)) -> {
          case evaluate(stdin, scope, search:, handlers:) {
            Error(report) -> Error(report)

            Ok(Literal(value)) -> {
              // TODO: Alltid json?
              let stdin_string = value.to_json(value) |> json.to_string
              let arguments = string_extra.words(command_string)

              Ok({
                use <- Loading
                use string <- result.try({
                  handlers.command(arguments, Some(stdin_string))
                })

                dynamic.string(string)
                |> decoder.run(value.decoder())
                |> result.map(Literal)
              })
            }

            Ok(source) -> Ok(Command(command:, stdin: Some(source)))
          }
        }
      }

    Fetch(method:, uri:, headers:, timeout:, body: None) -> {
      let placeholder = option.map(search, uri.percent_encode)

      case text.evaluate(uri, scope, placeholder:) {
        Error(report) -> Error(report)
        Ok(None) -> Ok(Fetch(method, uri, headers, timeout:, body: None))

        Ok(Some(string)) -> {
          use request <- result.map(build_request(method, string, headers))

          use <- Loading
          send_request(request, timeout, value.decoder(), handlers.http)
          |> result.map(Literal)
        }
      }
    }

    Fetch(method:, uri:, headers:, timeout:, body: Some(body)) -> {
      let placeholder = option.map(search, uri.percent_encode)

      case text.evaluate(uri, scope, placeholder:) {
        Error(report) -> Error(report)
        Ok(None) ->
          Ok(Fetch(method:, uri:, headers:, timeout:, body: Some(body)))

        Ok(Some(string)) ->
          case evaluate(body, scope, search:, handlers:) {
            Error(report) -> Error(report)

            Ok(Literal(value)) -> {
              use request <- result.map(
                build_request(method, string, headers)
                |> result.map(set_request_body(_, value)),
              )

              use <- Loading
              send_request(request, timeout, value.decoder(), handlers.http)
              |> result.map(Literal)
            }

            Ok(source) ->
              Ok(Fetch(method:, uri:, headers:, timeout:, body: Some(source)))
          }
      }
    }
  }
}

fn build_request(
  method: http.Method,
  uri: String,
  headers: List(http.Header),
) -> Result(RequestBuilder(Option(BytesTree)), Report(Error)) {
  use request <- result.map({
    uri.parse(uri)
    |> report.replace_error(error.BadProperty("url"))
    |> result.map(request_builder.new)
  })

  let request =
    request_builder.set_method(request, method)
    |> request_builder.set_header("accept", "application/json")
    |> request_builder.set_body(None)

  use request, #(key, value) <- list.fold(headers, request)
  request_builder.set_header(request, key, value)
}

fn set_request_body(
  request: RequestBuilder(v),
  value: Value,
) -> RequestBuilder(Option(BytesTree)) {
  request_builder.set_header(request, "content-type", "application/json")
  |> request_builder.set_body(Some(
    value.to_json(value)
    |> json.to_string_tree
    |> bytes_tree.from_string_tree,
  ))
}

fn send_request(
  request: RequestBuilder(body),
  timeout: Int,
  decoder: Decoder(Value),
  handler: fn(RequestBuilder(body), Int) ->
    Result(Response(BitArray), Report(Error)),
) -> Result(Value, Report(Error)) {
  use response <- result.try(handler(request, timeout))
  parse_json(response.body, decoder)
}

fn parse_json(bits: BitArray, decoder: Decoder(v)) -> Result(v, Report(Error)) {
  json.parse_bits(bits, decoder)
  |> report.map_error(error.JsonError)
}

pub fn decoder(
  dynamic: Dynamic,
  sources sources: custom.Sources,
) -> Result(Resetable, Report(Error)) {
  Ok(reset.try_new(source_decoder(dynamic, sources:), refs))
}

pub fn source_decoder(
  dynamic: Dynamic,
  sources sources: custom.Sources,
) -> Result(Source, Report(Error)) {
  seen_decoder(dynamic, seen: set.new(), sources:)
}

fn custom_decoder(
  name: String,
  seen seen: Set(String),
  custom custom: Dict(String, Dynamic),
  sources sources: custom.Sources,
) -> Result(Source, Report(Error)) {
  let recursive = report.error(error.Recursive(name))
  use <- bool.guard(set.contains(seen, name), recursive)
  let seen = set.insert(seen, name)

  case custom.get_source(sources, name) {
    Ok(dict) -> props.decode_dict(dict, kind_decoder(seen:, custom:, sources:))
    Error(Nil) -> report.error(error.UnknownKind(name))
  }
}

fn seen_decoder(
  dynamic: Dynamic,
  seen seen: Set(String),
  sources sources: custom.Sources,
) -> Result(Source, Report(Error)) {
  let custom = dict.new()
  case decoder.run(dynamic, decode.string) {
    Ok(name) -> custom_decoder(name, seen:, custom:, sources:)
    Error(..) -> props.decode(dynamic, kind_decoder(seen:, custom:, sources:))
  }
}

fn kind_decoder(
  seen seen: Set(String),
  custom custom: Dict(String, Dynamic),
  sources sources: custom.Sources,
) -> props.Try(Source) {
  use dict <- props.get_dict
  use <- return(state.from_result)

  case dict.to_list(dict) {
    [#("literal", dynamic)] ->
      decoder.run(dynamic, value.decoder())
      |> report.error_context(error.BadKind("literal"))
      |> result.map(Literal)

    [#("reference", dynamic)] ->
      text.id_decoder(dynamic)
      |> report.error_context(error.BadKind("reference"))
      |> result.map(Reference)

    [#("template", dynamic)] ->
      text.decoder(dynamic)
      |> report.error_context(error.BadKind("template"))
      |> result.map(Template)

    [#("command", dynamic)] -> {
      use <- return(report.error_context(_, error.BadKind("command")))

      use <- result.lazy_or({
        use command <- result.map(text.decoder(dynamic))
        Command(command:, stdin: None)
      })

      props.decode(dynamic, {
        use <- state.do(props.merge(custom))
        command_decoder(seen:, sources:)
      })
    }

    [#("fetch", dynamic)] -> {
      use <- return(report.error_context(_, error.BadKind("fetch")))

      use <- result.lazy_or({
        use uri <- result.map(text.decoder(dynamic))

        Fetch(
          method: http.Get,
          uri:,
          headers: [],
          timeout: default_timeout,
          body: None,
        )
      })

      props.decode(dynamic, {
        use <- state.do(props.merge(custom))
        fetch_decoder(seen:, sources:)
      })
    }

    [#("kind", dynamic)] ->
      decoder.run(dynamic, decode.string)
      |> result.try(custom_decoder(_, seen:, custom:, sources:))

    [#(name, dynamic)] ->
      decoder.run(dynamic, decode.dict(decode.string, decode.dynamic))
      |> result.try(custom_decoder(name, seen:, custom: _, sources:))

    bad -> report.error(error.BadFormat(dynamic_extra.from(bad)))
  }
}

fn fetch_decoder(
  seen seen: Set(String),
  sources sources: custom.Sources,
) -> props.Try(Source) {
  use <- state.try_do(props.check_keys(fetch_keys))
  use method <- props.try("method", method_decoder())
  use uri <- props.get("url", text.decoder)
  use headers <- props.try("headers", headers_decoder())

  use timeout <- props.try("timeout", {
    zero.new(default_timeout, decoder.from(decode.int))
  })

  use body <- props.try("body", zero.option(seen_decoder(_, seen:, sources:)))
  state.ok(Fetch(method:, uri:, headers:, timeout:, body:))
}

fn method_decoder() -> Zero(http.Method, Nil) {
  use dynamic <- zero.new(http.Get)
  use string <- result.try(decoder.run(dynamic, decode.string))
  http.parse_method(string.uppercase(string))
  |> report.replace_error(error.BadProperty("method"))
}

fn headers_decoder() -> Zero(List(#(String, String)), Nil) {
  use dynamic <- zero.list
  decoder.run(dynamic, decode.dict(decode.string, decode.string))
  |> report.error_context(error.BadProperty("headers"))
  |> result.map(dict.to_list)
}

fn command_decoder(
  seen seen: Set(String),
  sources sources: custom.Sources,
) -> props.Try(Source) {
  use <- state.try_do(props.check_keys(command_keys))
  use command <- props.get("command", text.decoder)
  use stdin <- props.try("stdin", zero.option(seen_decoder(_, seen:, sources:)))
  state.ok(Command(command:, stdin:))
}
