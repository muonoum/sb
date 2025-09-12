import filepath
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option
import gleam/result
import gleam/set
import pprint
import sb/extra
import sb/extra/dots
import sb/extra/path
import sb/extra/report.{type Report}
import sb/extra/state2.{type State} as state
import sb/extra/yaml
import sb/forms/access.{type Access}
import sb/forms/custom
import sb/forms/decoder
import sb/forms/error.{type Error}
import sb/forms/props.{type Props}
import sb/forms/task.{type Task}
import sb/forms/zero

pub type File {
  File(kind: Kind, path: String, documents: List(Dynamic))
}

pub type Kind {
  Custom(Custom)
  TasksV1(category: List(String), runners: Access, approvers: Access)
}

pub type Custom {
  CommandsV1
  FieldsV1
  FiltersV1
  SourcesV1
}

pub type Context {
  Context(
    task_data: List(File),
    custom_data: Dict(Custom, List(File)),
    custom: Dict(Custom, List(#(String, custom.Custom))),
    reports: List(Report(Error)),
  )
}

fn add_custom_data(kind: Custom, file: File) -> State(Nil, Context) {
  use context <- state.update()

  Context(..context, custom_data: {
    use kind <- dict.upsert(context.custom_data, kind)
    option.map(kind, list.prepend(_, file))
    |> option.unwrap([file])
  })
}

fn add_custom(
  kind: Custom,
  custom: #(String, custom.Custom),
) -> State(Nil, Context) {
  use context <- state.update()

  Context(..context, custom: {
    use kind <- dict.upsert(context.custom, kind)
    option.map(kind, list.prepend(_, custom))
    |> option.unwrap([custom])
  })
}

fn add_task(file: File) {
  use context <- state.update()
  Context(..context, task_data: [file, ..context.task_data])
}

fn add_report(report: Report(Error), path path: String) -> State(Nil, Context) {
  use context <- state.update()
  let report = report.context(report, error.PathContext(path))
  Context(..context, reports: [report, ..context.reports])
}

fn add_indexed_report(
  report: Report(Error),
  path path: String,
  index index: Int,
) -> State(Nil, Context) {
  report.context(report, error.IndexContext(index))
  |> add_report(path)
}

pub fn main() {
  load("priv/sb", "**/*.yaml")
  |> state.step(
    Context(
      task_data: [],
      custom_data: dict.new(),
      custom: dict.new(),
      reports: [],
    ),
  )
  |> pprint.debug
}

fn load(
  prefix: String,
  pattern: String,
) -> State(List(#(String, Task)), Context) {
  use <- state.do(
    state.sequence({
      use path <- list.map(path.wildcard(prefix, pattern))
      load_path(prefix, path)
    }),
  )

  use <- state.do(decode_custom(CommandsV1))
  use <- state.do(decode_custom(FiltersV1))
  use <- state.do(decode_custom(FieldsV1))
  use <- state.do(decode_custom(SourcesV1))

  decode_tasks()
}

fn load_path(prefix: String, path: String) -> State(Nil, Context) {
  case load_file(prefix, path) {
    Ok(File(kind: Custom(kind), ..) as file) -> add_custom_data(kind, file)
    Ok(File(kind: TasksV1(..), ..) as file) -> add_task(file)
    Error(report) -> add_report(report, path)
  }
}

fn load_file(prefix: String, path: String) -> Result(File, Report(Error)) {
  use dynamic <- result.try(
    yaml.decode_file(filepath.join(prefix, path))
    |> report.map_error(error.YamlError),
  )

  use docs <- result.try(decoder.run(dynamic, decode.list(decode.dynamic)))

  case docs {
    [] -> report.error(error.EmptyFile)

    [header, ..documents] -> {
      let header = dots.split(header)
      use kind <- result.try(props.decode(header, kind_decoder()))
      let documents = list.map(documents, dots.split)
      Ok(File(kind:, path:, documents:))
    }
  }
}

fn decode_tasks() -> State(List(#(String, Task)), Context) {
  use context: Context <- state.with(state.get())

  let sources =
    custom.Sources(dict.from_list(
      dict.get(context.custom, SourcesV1)
      |> result.unwrap([]),
    ))

  let fields =
    custom.Fields(dict.from_list(
      dict.get(context.custom, FieldsV1)
      |> result.unwrap([]),
    ))

  let filters =
    custom.Filters(dict.from_list(
      dict.get(context.custom, FiltersV1)
      |> result.unwrap([]),
    ))

  use <- extra.return(state.map(_, list.filter_map(_, extra.identity)))
  use <- extra.return(state.sequence)
  use file <- list.flat_map(context.task_data)
  use document, index <- list.index_map(file.documents)
  let add_report = add_indexed_report(_, file.path, index)
  case props.decode(document, task.decoder(filters:, fields:, sources:)) {
    Ok(task) -> state.return(Ok(#(task.id, task)))

    Error(report) -> {
      use <- state.do(add_report(report))
      state.return(Error(Nil))
    }
  }
}

fn decode_custom(kind: Custom) -> State(List(Nil), Context) {
  use context: Context <- state.with(state.get())

  let sources =
    dict.get(context.custom_data, kind)
    |> result.unwrap([])

  state.sequence(state.run(
    context: set.new(),
    state: state.sequence({
      use file <- list.flat_map(sources)
      use document, index <- list.index_map(file.documents)
      let add_report = add_indexed_report(_, file.path, index)

      case props.decode(document, custom.decoder()) {
        Error(report) -> state.return(add_report(report))

        Ok(#(id, custom)) -> {
          use context <- state.with(state.get())

          use <- bool.guard(
            set.contains(context, id),
            state.return(add_report(report.new(error.DuplicateId(id)))),
          )

          use <- state.do(state.put(set.insert(context, id)))
          state.return(add_custom(kind, #(id, custom)))
        }
      }
    }),
  ))
}

fn kind_decoder() -> Props(Kind) {
  use kind <- props.get("kind", decoder.from(decode.string))

  case kind {
    "commands/v1" -> props.succeed(Custom(CommandsV1))
    "fields/v1" -> props.succeed(Custom(FieldsV1))
    "filters/v1" -> props.succeed(Custom(FiltersV1))
    "sources/v1" -> props.succeed(Custom(SourcesV1))
    "tasks/v1" -> tasks_v1_decoder()
    unknown -> props.fail(report.new(error.UnknownKind(unknown)))
  }
}

fn tasks_v1_decoder() -> Props(Kind) {
  use category <- props.try("category", {
    zero.list(decoder.from(decode.list(decode.string)))
  })

  use runners <- props.try("runners", access.decoder())
  use approvers <- props.try("approvers", access.decoder())
  props.succeed(TasksV1(category:, runners:, approvers:))
}
