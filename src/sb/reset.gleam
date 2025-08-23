import gleam/bool
import gleam/set.{type Set}

pub type Reset(v) {
  Reset(value: v, initial: fn() -> v, refs: Set(String))
}

pub fn new(value: v, refs: List(String)) -> Reset(v) {
  Reset(value:, initial: fn() { value }, refs: set.from_list(refs))
}

pub fn map(reset: Reset(v), map: fn(v) -> v) -> Reset(v) {
  Reset(..reset, value: map(reset.value))
}

pub fn unwrap(reset: Reset(v)) -> v {
  reset.value
}

pub fn changed(reset: Reset(v), refs: Set(String)) -> Bool {
  let intersection = set.intersection(refs, reset.refs)
  set.is_empty(intersection)
}

pub fn maybe(reset: Reset(v), refs: Set(String)) -> Reset(v) {
  use <- bool.guard(!changed(reset, refs), reset)
  Reset(..reset, value: reset.initial())
}

pub fn maybe2(reset: Reset(v), refs: Set(String)) -> #(Reset(v), Bool) {
  let intersection = set.intersection(refs, reset.refs)
  use <- bool.guard(set.is_empty(intersection), #(reset, False))
  #(Reset(..reset, value: reset.initial()), True)
}
