import exception.{type Exception}
import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option, None, Some}
import gleam/result
import helpers
import sb/extra/report.{type Report}
import sb/forms/custom
import sb/forms/error.{type Error}
import sb/forms/props
import sb/forms/task.{type Task}

pub type Builder {
  TaskBuilder(
    input: String,
    sources: Option(custom.Sources),
    fields: Option(custom.Fields),
    filters: Option(custom.Filters),
    defaults: task.Defaults,
    loader: fn(String) -> Result(Dynamic, Exception),
  )
}

pub fn new(
  input: String,
  loader: fn(String) -> Result(Dynamic, Exception),
) -> Builder {
  TaskBuilder(
    input:,
    sources: None,
    fields: None,
    filters: None,
    defaults: task.empty_defaults(),
    loader:,
  )
}

pub fn set_defaults(builder: Builder, defaults: task.Defaults) -> Builder {
  TaskBuilder(..builder, defaults:)
}

pub fn set_custom_sources(builder: Builder, sources: custom.Sources) -> Builder {
  TaskBuilder(..builder, sources: Some(sources))
}

pub fn load_custom_sources(
  builder: Builder,
  input: String,
  loader: fn(String) -> Result(Dynamic, Exception),
) -> Result(Builder, Report(Error)) {
  use sources <- result.try(helpers.load_custom_sources(input, loader))
  Ok(set_custom_sources(builder, sources))
}

pub fn set_custom_fields(builder: Builder, fields: custom.Fields) -> Builder {
  TaskBuilder(..builder, fields: Some(fields))
}

pub fn load_custom_fields(
  builder: Builder,
  input: String,
  loader: fn(String) -> Result(Dynamic, Exception),
) -> Result(Builder, Report(Error)) {
  use fields <- result.try(helpers.load_custom_fields(input, loader))
  Ok(set_custom_fields(builder, fields))
}

pub fn set_custom_filters(builder: Builder, filters: custom.Filters) -> Builder {
  TaskBuilder(..builder, filters: Some(filters))
}

pub fn load_custom_filters(
  builder: Builder,
  input: String,
  loader: fn(String) -> Result(Dynamic, Exception),
) -> Result(Builder, Report(Error)) {
  use filters <- result.try(helpers.load_custom_filters(input, loader))
  Ok(set_custom_filters(builder, filters))
}

pub fn build(builder: Builder) -> Result(Task, Report(Error)) {
  load_task(
    builder.input,
    option.lazy_unwrap(builder.sources, custom.empty_sources),
    option.lazy_unwrap(builder.fields, custom.empty_fields),
    option.lazy_unwrap(builder.filters, custom.empty_filters),
    builder.loader,
  )
}

fn load_task(
  input: String,
  sources sources: custom.Sources,
  fields fields: custom.Fields,
  filters filters: custom.Filters,
  loader loader: fn(String) -> Result(Dynamic, _),
) -> Result(Task, Report(Error)) {
  use defaults, docs <- helpers.with_tasks_file(input, loader)
  let assert [doc, ..] = docs
  decode_task(doc, sources:, fields:, filters:, defaults:)
}

fn decode_task(
  dynamic: Dynamic,
  sources sources: custom.Sources,
  fields fields: custom.Fields,
  filters filters: custom.Filters,
  defaults defaults: task.Defaults,
) -> Result(Task, Report(Error)) {
  task.decoder(defaults:, sources:, fields:, filters:)
  |> props.decode(dynamic, _)
}
