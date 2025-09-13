import gleam/option.{type Option}
import sb/forms/options.{type Options}
import sb/forms/source.{type Source}
import sb/forms/value.{type Value}

// search?
// - "search member & .."
// - "search > member & .."

pub type Config(message) {
  Config(
    options: Options,
    placeholder: Option(String),
    is_loading: fn(Source) -> Bool,
    search_value: Option(String),
    applied_search: Option(String),
    search: fn(String) -> message,
    clear_search: message,
    select: fn(Value) -> message,
    debug: Bool,
  )
}

pub fn select(_selected, _config) {
  todo
}

pub fn multi_select(_selected, _config) {
  todo
}
