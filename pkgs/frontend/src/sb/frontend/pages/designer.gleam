import lustre/effect.{type Effect}
import lustre/element.{type Element}

pub opaque type Model {
  Model
}

pub type Message

pub fn init() -> #(Model, Effect(Message)) {
  #(Model, effect.none())
}

pub fn update(model: Model, _message: Message) -> #(Model, Effect(Message)) {
  #(model, effect.none())
}

pub fn view(_model: Model) -> Element(Message) {
  element.none()
}
