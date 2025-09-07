import gleam/int
import gleam/list
import lustre
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import sb/extra/report.{type Report}
import sb/forms/error.{type Error}
import sb/frontend/components/core
import sb/frontend/components/icons

type Loader =
  fn(List(Report(Error))) -> Message

pub opaque type Model {
  Model(handlers: Handlers, reports: List(Report(Error)))
}

pub opaque type Message {
  Load
  Receive(List(Report(Error)))
}

pub opaque type Handlers {
  Handlers(
    schedule: fn(Message) -> Effect(Message),
    load: fn(Loader) -> Effect(Message),
  )
}

pub fn app(
  schedule schedule: fn(Message) -> Effect(Message),
  load load: fn(Loader) -> Effect(Message),
) -> lustre.App(Nil, Model, Message) {
  let handlers = Handlers(schedule:, load:)
  lustre.component(init(_, handlers), update, view, options: [])
}

fn init(_flags, handlers: Handlers) -> #(Model, Effect(Message)) {
  let model = Model(handlers:, reports: [])
  #(model, effect.from(fn(dispatch) { dispatch(Load) }))
}

fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  let Model(handlers:, ..) = model

  case message {
    Load -> #(model, handlers.load(Receive))
    Receive(reports) -> #(Model(..model, reports:), handlers.schedule(Load))
  }
}

fn view(model: Model) -> Element(Message) {
  core.button(
    button: [attr.class("self-center")],
    label: [
      attr.class("flex items-center !no-underline"),
      attr.class("text-neutral-100 bg-red-800/80 text-shadow-25"),
    ],
    body: [
      icons.exclamation_triangle_outline([attr.class("stroke-2")]),
      html.text(int.to_string(list.length(model.reports))),
    ],
  )
}
