import lustre/effect.{type Effect}
import lustre/element.{type Element}

pub opaque type Model {
  Model(task_id: String)
}

pub type Message

pub fn init(task_id: String) -> #(Model, Effect(Message)) {
  #(Model(task_id:), effect.none())
}

pub fn update(model: Model, _message: Message) -> #(Model, Effect(Message)) {
  #(model, effect.none())
}

pub fn view(_model: Model) -> Element(Message) {
  element.none()
}
