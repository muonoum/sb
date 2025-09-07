import gleam/dynamic.{type Dynamic}
import sb/forms/access.{type Access}

pub type File {
  File(kind: Kind, path: String, docs: List(Dynamic))
}

pub type Kind {
  FieldsV1
  TasksV1(category: List(String), runners: Access, approvers: Access)
  FiltersV1
  CommandsV1
}
