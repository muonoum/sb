import gleam/dynamic/decode
import lustre/attribute.{attribute}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/event
import lustre/server_component as server
import plinth/browser/window
import sb/frontend/components/header
import sb/frontend/portals

pub opaque type Model {
  Model(task_id: String)
}

pub type Message {
  Reset
}

pub fn init(task_id: String) -> #(Model, Effect(Message)) {
  #(Model(task_id:), effect.none())
}

pub fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case message {
    Reset -> #(model, {
      use _dispatch <- effect.from
      window.reload()
    })
  }
}

pub fn view(model: Model) -> Element(Message) {
  element.fragment([
    portals.into_menu([
      header.inactive_menu("Oppgaver", "/oppgaver"),
      header.inactive_menu("Jobber", "/jobber"),
      header.inactive_menu("Hjelp", "/hjelp"),
    ]),
    server.element(
      [
        attribute("task-id", model.task_id),
        server.route("/components/task"),
        event.on("reset", decode.success(Reset)),
      ],
      [],
    ),
  ])
}
