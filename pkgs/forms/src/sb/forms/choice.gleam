import sb/forms/value.{type Value}

pub opaque type Choice {
  Choice(key: Value, value: Value)
}

pub fn new(key: Value, value: Value) -> Choice {
  Choice(key, value)
}

pub fn from_value(value: Value) -> Choice {
  case value {
    value.Pair(key, value) ->
      value.String(key)
      |> Choice(value)

    value -> Choice(value, value)
  }
}

pub fn key(choice: Choice) -> Value {
  choice.key
}

pub fn value(choice: Choice) -> Value {
  choice.value
}
