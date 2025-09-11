import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import sb/extra/report.{type Report}
import sb/extra/state
import sb/forms/access.{type Access}
import sb/forms/decoder
import sb/forms/error.{type Error}
import sb/forms/props
import sb/forms/zero

pub type File {
  File(kind: Kind, path: String, docs: List(Dynamic))
}

pub type Kind {
  CommandsV1
  FieldsV1
  FiltersV1
  SourcesV1
  TasksV1(category: List(String), runners: Access, approvers: Access)
}

pub fn is_tasks(file: File) -> Bool {
  case file {
    File(kind: TasksV1(..), ..) -> True
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

pub fn decoder() {
  use kind <- props.get("kind", decoder.from(decode.string))

  case kind {
    "fields/v1" -> props.succeed(FieldsV1)
    "filters/v1" -> props.succeed(FiltersV1)
    "sources/v1" -> props.succeed(SourcesV1)
    "tasks/v1" -> tasks_v1_decoder()
    _bad -> props.fail(report.new(error.BadKind(kind)))
  }
}

fn tasks_v1_decoder() -> state.State(Kind, Report(Error), props.Context) {
  use category <- props.try("category", {
    zero.list(decoder.from(decode.list(decode.string)))
  })

  use runners <- props.try("runners", access.decoder())
  use approvers <- props.try("approvers", access.decoder())
  props.succeed(TasksV1(category:, runners:, approvers:))
}
