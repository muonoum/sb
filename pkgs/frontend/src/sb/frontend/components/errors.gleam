import gleam/int
import gleam/list
import gleam/string
import lustre
import lustre/attribute as attr
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import sb/extra/function.{apply}
import sb/extra/report.{type Report}
import sb/extra/visibility.{type Visibility, Hidden, Visible}
import sb/forms/error.{type Error}
import sb/frontend/components/core
import sb/frontend/components/icons

pub type LoadMessage =
  fn(List(Report(Error))) -> Message

pub opaque type Model {
  Model(
    handlers: Handlers,
    reports: List(Report(Error)),
    visibility: Visibility,
  )
}

pub opaque type Message {
  Toggle
  Load
  Receive(List(Report(Error)))
}

pub opaque type Handlers {
  Handlers(
    schedule: fn(Message) -> Effect(Message),
    load: fn(LoadMessage) -> Effect(Message),
  )
}

pub fn app(
  schedule schedule: fn(Message) -> Effect(Message),
  load load: fn(LoadMessage) -> Effect(Message),
) -> lustre.App(Nil, Model, Message) {
  let handlers = Handlers(schedule:, load:)
  lustre.component(init(_, handlers), update, view, options: [])
}

fn init(_flags, handlers: Handlers) -> #(Model, Effect(Message)) {
  let model = Model(handlers:, reports: [], visibility: Hidden)
  #(model, effect.from(apply(Load)))
}

fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  let Model(handlers:, ..) = model

  case message, model.visibility {
    Load, _visibility -> #(model, handlers.load(Receive))

    Receive([]), Visible -> {
      let model = Model(..model, reports: [], visibility: Hidden)
      #(model, handlers.schedule(Load))
    }

    Receive(reports), _visibility -> {
      #(Model(..model, reports:), handlers.schedule(Load))
    }

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
  core.button(
    button: [event.on_click(Toggle), attr.class("group")],
    label: [
      attr.class("flex items-center"),
      attr.class(case model.visibility {
        Hidden -> "text-red-800/80"
        Visible -> "text-neutral-100 bg-red-800/80 bg-red-800/80 text-shadow-25"
      }),
    ],
    body: [
      icons.exclamation_triangle_outline([attr.class("stroke-2")]),
      html.text(int.to_string(list.length(model.reports))),
    ],
  )
}

fn error_reports(reports: List(Report(Error))) -> Element(Message) {
  html.div(
    [
      core.classes([
        "flex flex-col z-(--z-errors) overflow-y-scroll",
        "fixed inset-x-0 bottom-0 left-1/2 -translate-x-2/4",
        "rounded-t-lg px-4 py-3 w-(--sheet-width) max-h-[300px]",
        "font-mono font-medium bg-zinc-900 text-stone-300",
        "shadow-[0_10px_50px_20px_rgba(0_0_0/20%)]",
      ]),
    ],
    list.map(reports, view_report),
  )
}

fn view_report(report: Report(Error)) -> Element(Message) {
  html.div([attr.class("flex gap-2")], [
    element.text(string.inspect(report)),
  ])
}
