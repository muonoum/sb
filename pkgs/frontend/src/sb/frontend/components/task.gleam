import gleam/dict.{type Dict}
import gleam/string
import lustre
import lustre/attribute as attr
import lustre/component
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import sb/extra/report.{type Report}
import sb/forms/error.{type Error}
import sb/forms/task.{type Task}
import sb/frontend/components/core
import sb/frontend/portals

type Loader =
  fn(Result(Task, Report(Error))) -> Message

pub opaque type Handlers {
  Handlers(
    load: fn(String, Loader) -> Effect(Message),
    step: fn(Task, Dict(String, String), Loader) -> Effect(Message),
    schedule: fn(Int, Message) -> Effect(Message),
  )
}

pub opaque type Message {
  Load(String)
  Receive(Result(Task, Report(Error)))
}

pub opaque type Model {
  Model(handlers: Handlers)
}

pub fn app(
  load load: fn(String, Loader) -> Effect(Message),
  step step: fn(Task, Dict(String, String), Loader) -> Effect(Message),
  schedule schedule: fn(Int, Message) -> Effect(Message),
) -> lustre.App(Nil, Model, Message) {
  let handlers = Handlers(load:, step:, schedule:)

  lustre.component(init: init(_, handlers), update:, view:, options: [
    component.on_attribute_change("task-id", fn(string) {
      case string.trim(string) {
        "" -> Ok(Receive(report.error(error.BadId(""))))
        id -> Ok(Load(id))
      }
    }),
  ])
}

pub fn init(_flags, handlers: Handlers) -> #(Model, Effect(Message)) {
  #(Model(handlers:), effect.none())
}

pub fn update(_model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    Load(_) -> todo
    Receive(_) -> todo
  }
}

fn view(model: Model) -> Element(Message) {
  element.fragment([page_header(model), page(model)])
}

fn page_header(_model: Model) -> Element(Message) {
  let validated = True

  portals.into_actions([
    html.div([attr.class("flex gap-5")], [
      core.button(button: [], label: [], body: [
        html.text("Nullstill skjema"),
      ]),
      core.button(
        button: [
          attr.class("group"),
          attr.disabled(!validated),
        ],
        body: [html.text("Utfør oppgave")],
        label: [
          core.classes([
            "!no-underline transition-colors text-shadow-25 text-neutral-100",
            case validated {
              True -> "bg-emerald-600 group-hover:bg-emerald-700"
              False -> "bg-zinc-400"
            },
          ]),
        ],
      ),
    ]),
  ])
}

fn page(_model: Model) -> Element(Message) {
  todo
}
