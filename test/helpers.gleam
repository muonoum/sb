import exception.{type Exception}
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/list
import gleam/result
import gleeunit/should
import sb/extra/dots
import sb/extra/report.{type Report}
import sb/extra/state
import sb/extra_server/yaml
import sb/forms/custom
import sb/forms/error.{type Error}
import sb/forms/field.{type Field}
import sb/forms/handlers.{type Handlers}
import sb/forms/layout
import sb/forms/props
import sb/forms/scope.{type Scope}
import sb/forms/source.{type Source}
import sb/forms/task.{type Task}
import sb/store

pub fn start_store() {
  let name = process.new_name("store")
  let config =
    store.Config(prefix: "test_data/store", interval: 0, pattern: "**/*.yaml")
  store.start(name, config) |> should.be_ok
  process.named_subject(name)
}

pub fn start_store_with_no_errors() {
  let store = start_store()
  store.get_errors(store) |> should.equal([])
  store
}

pub fn decode_task(data: String) -> Result(Task, Report(Error)) {
  let dynamic =
    yaml.decode_string(data)
    |> should.be_ok

  let assert [doc, ..] =
    decode.run(dynamic, decode.list(decode.dynamic))
    |> should.be_ok

  dots.split(doc)
  |> props.decode(task.decoder(
    filters: custom.Filters(dict.new()),
    fields: custom.Fields(dict.new()),
    sources: custom.Sources(dict.new()),
    defaults: task.default_category(["Test"]),
  ))
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

pub fn run_evaluate(
  task1: Task,
  scope1: Scope,
  search: Dict(String, String),
  handlers: Handlers,
) -> #(Task, Scope) {
  let #(task2, scope2) = task.step(task1, scope1, search, handlers)
  use <- bool.lazy_guard(scope1 != scope2 || task1 != task2, fn() {
    run_evaluate(task2, scope2, search, handlers)
  })
  #(task2, scope2)
}

pub fn load_documents(
  data: String,
  loader: fn(String) -> Result(Dynamic, _),
) -> Result(List(Dynamic), Report(Error)) {
  use dynamic <- result.try(
    loader(data)
    |> report.map_error(error.YamlError),
  )

  use docs <- result.try(
    decode.run(dynamic, decode.list(decode.dynamic))
    |> report.map_error(error.DecodeError),
  )

  Ok(list.map(docs, dots.split))
}

pub fn load_custom(
  data: String,
  loader: fn(String) -> Result(Dynamic, Exception),
) -> Result(Dict(String, dict.Dict(String, Dynamic)), Report(Error)) {
  use docs <- result.try(load_documents(data, loader))
  use dict, dynamic <- list.try_fold(docs, dict.new())
  use custom <- result.try(custom.decode(dots.split(dynamic)))
  Ok(dict.merge(dict, custom))
}

pub fn decode_source_property(
  name: String,
  dynamic: dynamic.Dynamic,
  sources sources: custom.Sources,
) -> Result(Source, Report(Error)) {
  props.decode(dots.split(dynamic), {
    let decoder = props.decode(_, source.decoder(sources:))
    use source <- props.get(name, decoder)
    state.ok(source)
  })
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
