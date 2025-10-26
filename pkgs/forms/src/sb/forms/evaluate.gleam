import gleam/dict.{type Dict}
import gleam/option.{type Option}
import sb/extra/reader.{type Reader}
import sb/extra/reset.{type Reset, Reset}
import sb/forms/command.{type Command}
import sb/forms/handlers.{type Handlers}
import sb/forms/scope.{type Scope}

pub type Context {
  Context(
    scope: Scope,
    search: Dict(String, String),
    task_commands: Dict(String, Command),
    handlers: Handlers,
  )
}

pub fn with_scope(
  reader: Reader(v, Context),
  scope: Scope,
) -> Reader(v, Context) {
  use context <- reader.local(reader)
  Context(..context, scope:)
}

pub fn get_scope() -> Reader(Scope, Context) {
  use Context(scope:, ..) <- reader.bind(reader.ask)
  reader.return(scope)
}

pub fn get_handlers() -> Reader(Handlers, Context) {
  use Context(handlers:, ..) <- reader.bind(reader.ask)
  reader.return(handlers)
}

pub fn get_task_commands() -> Reader(Dict(String, Command), Context) {
  use Context(task_commands:, ..) <- reader.bind(reader.ask)
  reader.return(task_commands)
}

pub fn get_search(id: String) -> Reader(Option(String), Context) {
  use Context(search:, ..) <- reader.bind(reader.ask)
  option.from_result(dict.get(search, id))
  |> reader.return
}

// TODO: Her eller i reset.gleam?
pub fn reset(
  reset: Reset(v),
  then: fn(v) -> Reader(v, ctx),
) -> Reader(Reset(v), ctx) {
  let Reset(value:, ..) = reset
  use value <- reader.map(then(value))
  Reset(..reset, value:)
}
