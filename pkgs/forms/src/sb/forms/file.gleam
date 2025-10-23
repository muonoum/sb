import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import sb/extra/report
import sb/extra/state
import sb/forms/access
import sb/forms/decoder
import sb/forms/error
import sb/forms/props
import sb/forms/task
import sb/forms/zero

const task_v1_keys = ["kind", "category", "runners", "approvers"]

pub type File {
  File(kind: Kind, path: String, documents: List(Dynamic))
}

pub type Kind {
  Empty
  CommandsV1
  FieldsV1
  FiltersV1
  SourcesV1
  NotifiersV1
  TasksV1(task.Defaults)
}

pub fn empty(path: String) -> File {
  File(kind: Empty, path:, documents: [])
}

pub fn tasks(file: File) -> Result(#(String, List(Dynamic), task.Defaults), Nil) {
  case file {
    File(kind: TasksV1(defaults), path:, documents:) ->
      Ok(#(path, documents, defaults))
    _else -> Error(Nil)
  }
}

pub fn commands(file: File) -> Result(File, Nil) {
  case file {
    File(kind: CommandsV1, ..) -> Ok(file)
    _else -> Error(Nil)
  }
}

pub fn fields(file: File) -> Result(File, Nil) {
  case file {
    File(kind: FieldsV1, ..) -> Ok(file)
    _else -> Error(Nil)
  }
}

pub fn filters(file: File) -> Result(File, Nil) {
  case file {
    File(kind: FiltersV1, ..) -> Ok(file)
    _else -> Error(Nil)
  }
}

pub fn sources(file: File) -> Result(File, Nil) {
  case file {
    File(kind: SourcesV1, ..) -> Ok(file)
    _else -> Error(Nil)
  }
}

pub fn notifiers(file: File) -> Result(File, Nil) {
  case file {
    File(kind: NotifiersV1, ..) -> Ok(file)
    _else -> Error(Nil)
  }
}

pub fn decoder() -> props.Try(Kind) {
  use kind <- props.get("kind", decoder.from(decode.string))

  case kind {
    "commands/v1" -> state.ok(CommandsV1)
    "fields/v1" -> state.ok(FieldsV1)
    "filters/v1" -> state.ok(FiltersV1)
    "notifiers/v1" -> state.ok(NotifiersV1)
    "sources/v1" -> state.ok(SourcesV1)
    "tasks/v1" -> tasks_v1_decoder()
    bad -> state.error(report.new(error.BadKind(bad)))
  }
}

fn tasks_v1_decoder() -> props.Try(Kind) {
  use <- state.do(props.check_keys(task_v1_keys))

  use category <- props.try("category", {
    zero.list(decoder.from(decode.list(decode.string)))
  })

  use runners <- props.try("runners", access.decoder(access.none()))
  use approvers <- props.try("approvers", access.decoder(access.none()))
  let defaults = task.Defaults(category:, runners:, approvers:)
  state.ok(TasksV1(defaults))
}
