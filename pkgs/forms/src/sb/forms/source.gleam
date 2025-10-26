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
import sb/extra/function.{compose, return}
import sb/extra/reader.{type Reader}
import sb/extra/report.{type Report}
import sb/extra/request_builder.{type RequestBuilder}
import sb/extra/reset.{type Reset}
import sb/extra/state
import sb/extra/string as string_extra
import sb/forms/custom
import sb/forms/decoder
import sb/forms/error.{type Error}
import sb/forms/evaluate
import sb/forms/props
import sb/forms/scope
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
  search: Option(String),
) -> Reader(Result(Source, Report(Error)), evaluate.Context) {
  case source {
    Loading(load) -> reader.return(load())
    Literal(value) -> reader.return(Ok(Literal(value)))
    Reference(id) -> evaluate_reference(id)
    Template(text) -> evaluate_template(text)
    Command(command:, stdin:) -> evaluate_command(command:, stdin:, search:)

    Fetch(method:, uri:, headers:, timeout:, body:) ->
      evaluate_fetch(method:, uri:, headers:, timeout:, body:, search:)
  }
}

fn evaluate_reference(
  id: String,
) -> Reader(Result(Source, Report(Error)), evaluate.Context) {
  use scope <- reader.bind(evaluate.get_scope())
  use <- return(reader.return)

  case scope.value(scope, id) {
    Some(Ok(value)) -> Ok(Literal(value))
    Some(Error(_)) | None -> Ok(Reference(id))
  }
}

fn evaluate_template(
  text: Text,
) -> Reader(Result(Source, Report(Error)), evaluate.Context) {
  use scope <- reader.bind(evaluate.get_scope())
  use <- return(reader.return)

  case text.evaluate(text, scope, placeholder: None) {
    Error(report) -> Error(report)
    Ok(None) -> Ok(Template(text))
    Ok(Some(string)) -> Ok(Literal(value.String(string)))
  }
}

fn evaluate_command(
  command command: Text,
  stdin stdin: Option(Source),
  search search: Option(String),
) -> Reader(Result(Source, Report(Error)), evaluate.Context) {
  use scope <- reader.bind(evaluate.get_scope())
  let passthrough = fn(stdin) { reader.return(Ok(Command(command:, stdin:))) }

  use command <- reader.try(
    text.evaluate(command, scope, placeholder: search)
    |> reader.return,
  )

  case command, stdin {
    None, _stdin -> passthrough(None)
    Some(command), None -> run_command(command:, stdin: None)

    Some(command), Some(stdin) -> {
      use stdin <- reader.try(evaluate(stdin, search))

      case stdin {
        Literal(value) -> run_command(command:, stdin: Some(value))
        source -> passthrough(Some(source))
      }
    }
  }
}

fn run_command(
  command command: String,
  stdin stdin: Option(Value),
) -> Reader(Result(Source, Report(Error)), evaluate.Context) {
  use task_commands <- reader.bind(evaluate.get_task_commands())
  use handlers <- reader.bind(evaluate.get_handlers())
  use <- return(compose(Ok, reader.return))
  use <- Loading

  use output <- result.try({
    // TODO: Stdin blir alltid tolket som JSON
    let arguments = string_extra.words(command)
    let stdin = option.map(stdin, compose(value.to_json, json.to_string))
    handlers.command(arguments, stdin, task_commands)
    |> result.map(dynamic.string)
  })

  decoder.run(output, value.decoder())
  |> result.map(Literal)
}

fn evaluate_fetch(
  method method: http.Method,
  uri uri: Text,
  headers headers: List(#(String, String)),
  timeout timeout: Int,
  body body: Option(Source),
  search search: Option(String),
) -> Reader(Result(Source, Report(Error)), evaluate.Context) {
  use scope <- reader.bind(evaluate.get_scope())
  let placeholder = option.map(search, uri.percent_encode)

  let passthrough = fn() {
    reader.return(Ok(Fetch(method:, uri:, headers:, timeout:, body:)))
  }

  use uri <- reader.try(
    text.evaluate(uri, scope, placeholder:)
    |> reader.return,
  )

  case uri, body {
    None, _body -> passthrough()
    Some(uri), None -> run_fetch(method:, uri:, headers:, timeout:, body: None)

    Some(uri), Some(body) -> {
      use body <- reader.try(evaluate(body, search))

      case body {
        Literal(value) ->
          run_fetch(method:, uri:, headers:, timeout:, body: Some(value))
        _source -> passthrough()
      }
    }
  }
}

fn run_fetch(
  method method: http.Method,
  uri uri: String,
  headers headers: List(#(String, String)),
  timeout timeout: Int,
  body body: Option(Value),
) -> Reader(Result(Source, Report(Error)), evaluate.Context) {
  use handlers <- reader.bind(evaluate.get_handlers())
  use <- return(reader.return)
  use request <- result.map(build_request(method, uri, headers))
  use <- Loading

  let request =
    option.map(body, set_request_body(request, _))
    |> option.unwrap(request)

  send_request(request, timeout, value.decoder(), handlers.http)
  |> result.map(Literal)
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
