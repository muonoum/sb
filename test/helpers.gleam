import envoy
import exception.{type Exception}
import gleam/bit_array
import gleam/bool
import gleam/bytes_tree
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, Some}
import gleam/result
import gleam/string
import gleam/uri
import gleam_community/ansi
import gleeunit/should
import sb/extra/dots
import sb/extra/function.{return}
import sb/extra/list as list_extra
import sb/extra/report.{type Report}
import sb/extra/request_builder.{type RequestBuilder}
import sb/extra/reset
import sb/extra/state
import sb/forms/custom
import sb/forms/debug
import sb/forms/decoder
import sb/forms/error.{type Error}
import sb/forms/field.{type Field}
import sb/forms/file
import sb/forms/filter
import sb/forms/handlers.{type Handlers}
import sb/forms/kind
import sb/forms/layout
import sb/forms/props
import sb/forms/source.{type Source}
import sb/forms/task.{type Task}
import sb/forms/value.{type Value}
import sb/mock
import sb/store

pub fn start_store(prefix: String) {
  let name = process.new_name("store")
  let config = store.Config(prefix:, interval: 0, pattern: "**/*.yaml")
  store.start(name, config) |> should.be_ok
  process.named_subject(name)
}

pub fn start_store_with_no_errors(prefix: String) {
  let store = start_store(prefix)
  store.get_reports(store) |> should.equal([])
  store
}

pub fn load_documents(
  input: String,
  loader: fn(String) -> Result(Dynamic, _),
) -> Result(List(Dynamic), Report(Error)) {
  use dynamic <- result.try(report.map_error(loader(input), error.YamlError))
  use docs <- result.try(decoder.run(dynamic, decode.list(decode.dynamic)))
  Ok(list.map(docs, dots.split))
}

pub fn load_file(
  input: String,
  loader: fn(String) -> Result(Dynamic, _),
) -> Result(#(file.Kind, List(Dynamic)), Report(Error)) {
  use docs <- result.try(load_documents(input, loader))
  use header, docs <- list_extra.deconstruct(docs, or: Ok(#(file.Empty, [])))
  use kind <- result.try(props.decode(dots.split(header), file.decoder()))
  Ok(#(kind, list.map(docs, dots.split)))
}

pub fn with_tasks_file(
  input: String,
  loader: fn(String) -> Result(Dynamic, _),
  then: fn(task.Defaults, List(Dynamic)) -> Result(v, Report(Error)),
) -> Result(v, Report(Error)) {
  use file <- result.try(load_file(input, loader))
  let assert #(file.TasksV1(defaults), docs) = file
  then(defaults, docs)
}

pub fn load_custom(
  input: String,
  loader: fn(String) -> Result(Dynamic, Exception),
) -> Result(Dict(String, dict.Dict(String, Dynamic)), Report(Error)) {
  use docs <- result.try(load_documents(input, loader))
  use dict, dynamic <- list.try_fold(docs, dict.new())
  use custom <- result.try(custom.decode(dots.split(dynamic)))
  Ok(dict.merge(dict, custom))
}

pub fn with_custom_fields_file(
  input: String,
  loader: fn(String) -> Result(Dynamic, _),
  then: fn(List(Dynamic)) -> Result(v, Report(Error)),
) -> Result(v, Report(Error)) {
  use file <- result.try(load_file(input, loader))
  let assert #(file.FieldsV1, docs) = file
  then(docs)
}

pub fn load_custom_fields(
  input: String,
  loader: fn(String) -> Result(Dynamic, _),
) -> Result(custom.Fields, Report(Error)) {
  use <- return(result.map(_, custom.Fields))
  use <- return(result.map(_, dict.from_list))
  use docs <- with_custom_fields_file(input, loader)
  use doc <- list.try_map(docs)
  props.decode(dots.split(doc), custom.decoder(kind.builtin))
}

pub fn with_custom_sources_file(
  input: String,
  loader: fn(String) -> Result(Dynamic, _),
  then: fn(List(Dynamic)) -> Result(v, Report(Error)),
) -> Result(v, Report(Error)) {
  use file <- result.try(load_file(input, loader))
  let assert #(file.SourcesV1, docs) = file
  then(docs)
}

pub fn load_custom_sources(
  input: String,
  loader: fn(String) -> Result(Dynamic, _),
) -> Result(custom.Sources, Report(Error)) {
  use <- return(result.map(_, custom.Sources))
  use <- return(result.map(_, dict.from_list))
  use docs <- with_custom_sources_file(input, loader)
  use doc <- list.try_map(docs)
  props.decode(dots.split(doc), custom.decoder(source.builtin))
}

pub fn with_custom_filters_file(
  input: String,
  loader: fn(String) -> Result(Dynamic, _),
  then: fn(List(Dynamic)) -> Result(v, Report(Error)),
) -> Result(v, Report(Error)) {
  use file <- result.try(load_file(input, loader))
  let assert #(file.FiltersV1, docs) = file
  then(docs)
}

pub fn load_custom_filters(
  input: String,
  loader: fn(String) -> Result(Dynamic, _),
) -> Result(custom.Filters, Report(Error)) {
  use <- return(result.map(_, custom.Filters))
  use <- return(result.map(_, dict.from_list))
  use docs <- with_custom_filters_file(input, loader)
  use doc <- list.try_map(docs)
  props.decode(dots.split(doc), custom.decoder(filter.builtin))
}

pub fn debug_task(label: String, task: fn() -> Task) -> Task {
  let debug = envoy.get("DEBUG")
  use <- bool.lazy_guard(debug == Error(Nil), task)
  let task = task()

  let padding_length = int.max(0, 30 - string.length(label))
  let padding = list.repeat("=", padding_length) |> string.join("")
  let string = ansi.bold(ansi.grey("==[" <> label <> "]" <> padding))
  io.println("\n" <> string <> "\n" <> debug.task(task))

  task
}

pub fn decode_field(
  dynamic: Dynamic,
  sources sources: custom.Sources,
  fields fields: custom.Fields,
  filters filters: custom.Filters,
) -> Result(#(String, Field), Report(Error)) {
  let decoder = field.decoder(sources:, fields:, filters:)
  props.decode(dots.split(dynamic), decoder)
}

pub fn decode_source_property(
  dynamic: dynamic.Dynamic,
  name: String,
  sources sources: custom.Sources,
) -> Result(Source, Report(Error)) {
  props.decode(dots.split(dynamic), {
    use source <- props.get(name, source.source_decoder(_, sources:))
    state.ok(source)
  })
}

pub fn field_errors(task: Task) {
  let results = case task.layout {
    layout.Grid(results:, ..) -> results
    layout.Ids(results:, ..) -> results
    layout.Results(results:) -> results
  }

  use result <- list.filter_map(results)

  case result {
    Error(report) -> Ok(report)
    Ok(..) -> Error(Nil)
  }
}

pub fn field_value(
  task: Task,
  field_id: String,
  handlers handlers: Handlers,
) -> Option(Result(Value, Report(Error))) {
  dict.get(task.fields, field_id)
  |> result.map(field.value(_, handlers:))
  |> should.be_ok
}

pub fn some_field_value(
  task: Task,
  field_id: String,
  handlers handlers: Handlers,
) -> Result(Value, Report(Error)) {
  field_value(task, field_id, handlers:)
  |> should.be_some
}

pub fn ok_field_value(
  task: Task,
  field_id: String,
  handlers handlers: Handlers,
) -> Value {
  some_field_value(task, field_id, handlers:)
  |> should.be_ok
}

pub fn error_field_value(
  task: Task,
  field_id: String,
  handlers handlers: Handlers,
) -> Report(Error) {
  some_field_value(task, field_id, handlers:)
  |> should.be_error
}

pub fn field_sources(
  task: Task,
  field_id: String,
) -> List(Result(Source, Report(Error))) {
  let field = dict.get(task.fields, field_id) |> should.be_ok
  let sources = kind.sources(field.kind)
  list.map(sources, reset.unwrap)
}

pub fn field_options(task: Task, field_id: String) {
  let field = dict.get(task.fields, field_id) |> should.be_ok
  case field.kind {
    kind.Checkbox(options:, ..)
    | kind.MultiSelect(options:, ..)
    | kind.Radio(options:, ..)
    | kind.Select(options:, ..) -> Ok(options)
    _else -> Error(Nil)
  }
}

pub fn multi_line(string: String) -> String {
  let lines = {
    use line <- list.filter_map(string.split(string, "\n"))
    use <- bool.guard(string.trim(line) == "", Error(Nil))

    let leading = {
      use leading, string, count <- function.fix2

      case string {
        " " <> rest -> leading(rest, count + 1)
        string -> #(string, count)
      }
    }

    Ok(leading(line, 0))
  }

  use #(first, first_leading), rest <- list_extra.deconstruct(lines, or: "")

  let rest = {
    use #(line, leading) <- list.map(rest)
    let leading = int.max(leading - first_leading, 0)
    list.repeat(" ", leading) |> string.join("") <> line
  }

  string.join([first, ..rest], "\n")
}

pub fn lines(lines: List(String)) {
  string.join(lines, "\n")
}

pub fn strings(list: List(String)) -> Value {
  value.List(list.map(list, value.String))
}

pub fn http_handler(
  request: RequestBuilder(Option(bytes_tree.BytesTree)),
  _timeout: Int,
) -> Result(Response(BitArray), Report(Error)) {
  let base_uri =
    uri.Uri(
      ..uri.empty,
      scheme: Some("http"),
      host: Some("localhost"),
      port: Some(80),
    )

  use request <- result.try(
    request.build(base_uri)
    |> report.replace_error(error.BadRequest),
  )

  case request.method, request.body, request.path_segments(request) {
    http.Post, Some(body), ["mock", "echo"] ->
      ok_response(bytes_tree.to_bit_array(body))

    _method, option.None, ["mock", "echo"] -> bad_request_response()

    http.Get, option.None, ["mock", "lorem", "sentences", min, max] ->
      case int.parse(min), int.parse(max) {
        Ok(min), Ok(max) ->
          mock.lorem_sentences(min, max)
          |> json.array(json.string)
          |> json.to_string
          |> bit_array.from_string
          |> ok_response

        _min, _max -> bad_request_response()
      }

    _method, _body, ["mock", "lorem", "sentences", _min, _max] ->
      bad_request_response()

    _method, _body, _segments -> not_found_response()
  }
}

pub fn response(status: Int, body: BitArray) -> Result(Response(BitArray), _) {
  response.new(status)
  |> response.set_body(body)
  |> Ok
}

pub fn ok_response(body: BitArray) -> Result(Response(BitArray), _) {
  response(200, body)
}

pub fn bad_request_response() -> Result(Response(BitArray), _) {
  response(400, bit_array.from_string(""))
}

pub fn not_found_response() -> Result(Response(BitArray), _) {
  response(404, bit_array.from_string(""))
}
