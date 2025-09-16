import gleam/option.{type Option, None, Some}

pub type Status {
  Resolved
  Reloading
}

pub type Loadable(a, e) {
  Empty
  Loading
  Loaded(Status, a)
  Failed(Status, e, Option(a))
}

pub fn succeed(value: v) -> Loadable(v, _) {
  Loaded(Resolved, value)
}

pub fn fail(error: e, value: Option(v)) -> Loadable(v, e) {
  Failed(Resolved, error, value)
}

pub fn reload(loadable: Loadable(_, _)) -> Loadable(_, _) {
  case loadable {
    Empty -> Loading
    Loading -> Loading
    Loaded(_status, value) -> Loaded(Reloading, value)
    Failed(_status, error, value) -> Failed(Reloading, error, value)
  }
}

pub fn map(loadable: Loadable(a, _), mapper: fn(a) -> b) -> Loadable(b, _) {
  case loadable {
    Empty -> Empty
    Loading -> Loading
    Loaded(status, value) -> Loaded(status, mapper(value))
    Failed(status, error, Some(value)) ->
      Failed(status, error, Some(mapper(value)))
    Failed(status, error, None) -> Failed(status, error, None)
  }
}
