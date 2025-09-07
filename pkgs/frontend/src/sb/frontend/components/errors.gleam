import gleam/int
import gleam/list
import lustre
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import sb/extra.{type Visibility, Hidden, Visible}
import sb/extra/report.{type Report}
import sb/forms/error.{type Error}
import sb/frontend/components/core
import sb/frontend/components/icons

type Loader =
  fn(List(Report(Error))) -> Message

pub opaque type Model {
  Model(
    handlers: Handlers,
    reports: List(Report(Error)),
    visibility: Visibility,
  )
}

pub opaque type Message {
  Load
  Receive(List(Report(Error)))
  Toggle
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
  let model = Model(handlers:, reports: [], visibility: Hidden)
  #(model, effect.from(fn(dispatch) { dispatch(Load) }))
}

fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  let Model(handlers:, ..) = model

  case message, model.visibility {
    Load, _visibility -> #(model, handlers.load(Receive))

    Receive([]), Visible -> #(
      Model(..model, reports: [], visibility: Hidden),
      handlers.schedule(Load),
    )

    Receive(reports), _visibility -> #(
      Model(..model, reports:),
      handlers.schedule(Load),
    )

    Toggle, Hidden -> #(Model(..model, visibility: Visible), effect.none())
    Toggle, Visible -> #(Model(..model, visibility: Hidden), effect.none())
  }
}

fn view(model: Model) -> Element(Message) {
  element.fragment([
    case model.reports {
      [] -> element.none()
      _else -> error_button(model)
    },
    case model.visibility, model.reports {
      Hidden, _reports | Visible, [] -> element.none()
      Visible, reports -> error_reports(reports)
    },
  ])
}

fn error_button(model: Model) -> Element(Message) {
  // TODO: Fill height

  core.button(
    button: [event.on_click(Toggle), attr.class("self-center")],
    label: [
      attr.class("flex items-center !no-underline"),
      case model.visibility {
        Hidden -> attr.class("text-red-800/80")
        Visible -> attr.class("text-neutral-100 bg-red-800/80 text-shadow-25")
      },
    ],
    body: [
      icons.exclamation_triangle_outline([attr.class("stroke-2")]),
      html.text(int.to_string(list.length(model.reports))),
    ],
  )
}

fn error_reports(_reports: List(Report(Error))) -> Element(Message) {
  element.none()
}
