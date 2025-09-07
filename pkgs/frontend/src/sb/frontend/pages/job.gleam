import lustre/effect.{type Effect}
import lustre/element.{type Element}

pub opaque type Model {
  Model(job_id: String)
}

pub type Message

pub fn init(job_id: String) -> #(Model, Effect(Message)) {
  #(Model(job_id:), effect.none())
}

pub fn update(model: Model, _message: Message) -> #(Model, Effect(Message)) {
  #(model, effect.none())
}

pub fn view(_model: Model) -> Element(Message) {
  element.none()
}
