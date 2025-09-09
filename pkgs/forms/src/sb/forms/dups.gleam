import gleam/set.{type Set}
import sb/extra/report.{type Report}
import sb/forms/error.{type Error}

pub opaque type Dups {
  Dups(ids: Set(String), names: Set(#(String, List(String))))
}

pub fn new() -> Dups {
  Dups(ids: set.new(), names: set.new())
}

pub fn id(
  dups: Dups,
  id: String,
  then: fn(Dups) -> #(Dups, Result(v, Report(Error))),
) -> #(Dups, Result(v, Report(Error))) {
  case set.contains(dups.ids, id) {
    True -> #(dups, report.error(error.DuplicateId(id)))

    False ->
      set.insert(dups.ids, id)
      |> Dups(names: dups.names, ids: _)
      |> then
  }
}

pub fn names(
  dups: Dups,
  name: String,
  category: List(String),
  then: fn(Dups) -> #(Dups, Result(v, Report(Error))),
) -> #(Dups, Result(v, Report(Error))) {
  case set.contains(dups.names, #(name, category)) {
    True -> #(dups, report.error(error.DuplicateNames(name, category)))

    False ->
      set.insert(dups.names, #(name, category))
      |> Dups(ids: dups.ids, names: _)
      |> then
  }
}
