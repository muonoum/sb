import filepath
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None}
import gleam/result
import gleam/set
import pprint
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
    custom: Dict(Custom, #(String, custom.Custom)),
    reports: List(Report(Error)),
  )
}

fn add_custom(kind: Custom, file: File) -> State(Nil, Context) {
  use context <- state.update()

  Context(..context, custom_data: {
    use kind <- dict.upsert(context.custom_data, kind)

    option.map(kind, list.prepend(_, file))
    |> option.unwrap([file])
  })
}

fn add_task(file: File) {
  use context <- state.update()
  Context(..context, task_data: [file, ..context.task_data])
}

fn add_report(
  report: Report(Error),
  path path: String,
  index index: Option(Int),
) -> State(Nil, Context) {
  use context <- state.update()
  let report = report.context(report, error.PathContext(path))

  Context(..context, reports: {
    option.map(index, error.IndexContext)
    |> option.map(report.context(report, _))
    |> option.unwrap(report)
    |> list.prepend(context.reports, _)
  })
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

fn load(prefix: String, pattern: String) {
  path.wildcard(prefix, pattern)
  |> list.map(load_path(prefix, _))
  |> state.sequence
  |> state.do(decode_custom)
}

fn decode_custom() -> State(_, Context) {
  use context: Context <- state.with(state.get())

  let sources =
    dict.get(context.custom_data, SourcesV1)
    |> result.unwrap([])

  let custom =
    state.run(
      context: set.new(),
      state: state.sequence({
        use file <- list.flat_map(sources)
        use dynamic <- list.map(file.documents)

        case props.decode(dynamic, custom.decoder()) {
          Error(report) -> state.return(Error(report))

          Ok(#(id, custom)) -> {
            use context <- state.with(state.get())

            use <- bool.guard(
              set.contains(context, id),
              state.return(report.error(error.DuplicateId(id))),
            )

            use <- state.do(state.put(set.insert(context, id)))
            state.return(Ok(#(id, custom)))
          }
        }
      }),
    )
    |> echo

  todo
}

fn load_path(prefix: String, path: String) -> State(Nil, Context) {
  case load_file(prefix, path) {
    Ok(File(kind: Custom(kind), ..) as file) -> add_custom(kind, file)
    Ok(File(kind: TasksV1(..), ..) as file) -> add_task(file)
    Error(report) -> add_report(report, path, index: None)
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
