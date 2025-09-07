import lustre/effect.{type Effect}

pub type Model {
  Model
}

pub type Message

pub fn init() -> #(Model, Effect(Message)) {
  #(Model, effect.none())
}

pub fn update(model: Model, _message: Message) -> #(Model, Effect(Message)) {
  #(model, effect.none())
}
