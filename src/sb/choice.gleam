import sb/value.{type Value}

pub opaque type Choice {
  Choice(key: Value, value: Value)
}

pub fn new(key: Value, value: Value) -> Choice {
  Choice(key, value)
}

pub fn key(choice: Choice) -> Value {
  choice.key
}

pub fn value(choice: Choice) -> Value {
  choice.value
}
