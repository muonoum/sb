import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import sb/extra/report
import sb/extra/state_eval as state
import sb/forms/access
import sb/forms/decoder
import sb/forms/error
import sb/forms/props.{type Props}
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

pub fn is_tasks(file: File) -> Bool {
  case file {
    File(kind: TasksV1(..), ..) -> True
    _else -> False
  }
}

pub fn is_commands(file: File) -> Bool {
  case file {
    File(kind: CommandsV1, ..) -> True
    _else -> False
  }
}

pub fn is_fields(file: File) -> Bool {
  case file {
    File(kind: FieldsV1, ..) -> True
    _else -> False
  }
}

pub fn is_filters(file: File) -> Bool {
  case file {
    File(kind: FiltersV1, ..) -> True
    _else -> False
  }
}

pub fn is_sources(file: File) -> Bool {
  case file {
    File(kind: SourcesV1, ..) -> True
    _else -> False
  }
}

pub fn is_notifiers(file: File) -> Bool {
  case file {
    File(kind: NotifiersV1, ..) -> True
    _else -> False
  }
}

pub fn decoder() {
  use kind <- props.get("kind", decoder.from(decode.string))

  case kind {
    "commands/v1" -> props.succeed(CommandsV1)
    "fields/v1" -> props.succeed(FieldsV1)
    "filters/v1" -> props.succeed(FiltersV1)
    "notifiers/v1" -> props.succeed(NotifiersV1)
    "sources/v1" -> props.succeed(SourcesV1)
    "tasks/v1" -> tasks_v1_decoder()
    bad -> props.fail(report.new(error.bad_format(bad)))
  }
}

fn tasks_v1_decoder() -> Props(Kind) {
  use <- state.do(props.check_keys(task_v1_keys))

  use category <- props.try("category", {
    zero.list(decoder.from(decode.list(decode.string)))
  })

  use runners <- props.try("runners", access.decoder(access.none()))
  use approvers <- props.try("approvers", access.decoder(access.none()))
  let defaults = task.Defaults(category:, runners:, approvers:)
  props.succeed(TasksV1(defaults))
}
