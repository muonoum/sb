import gleam/list
import gleam/set.{type Set}

pub fn deconstruct(
  list: List(a),
  or empty: b,
  then next: fn(a, List(a)) -> b,
) -> b {
  case list {
    [] -> empty
    [first, ..rest] -> next(first, rest)
  }
}

pub fn unique(values: List(v)) -> Result(List(v), List(v)) {
  unique_loop(values, oks: [], dups: [], seen: set.new())
}

fn unique_loop(
  values: List(v),
  oks oks: List(v),
  dups dups: List(v),
  seen seen: Set(v),
) -> Result(List(v), List(v)) {
  case values, dups {
    [], [] -> Ok(list.reverse(oks))
    [], _dups -> Error(list.reverse(dups))

    [v, ..vs], _dups ->
      case set.contains(seen, v) {
        True -> unique_loop(vs, oks:, dups: [v, ..dups], seen:)

        False ->
          unique_loop(vs, dups:, oks: [v, ..oks], seen: set.insert(seen, v))
      }
  }
}

pub fn partition_map(
  list: List(a),
  with categorise: fn(a) -> Result(b, Nil),
) -> #(List(b), List(a)) {
  partition_map_loop(list, categorise, [], [])
}

fn partition_map_loop(
  list: List(a),
  categorise: fn(a) -> Result(b, Nil),
  trues: List(b),
  falses: List(a),
) -> #(List(b), List(a)) {
  case list {
    [] -> #(list.reverse(trues), list.reverse(falses))

    [first, ..rest] ->
      case categorise(first) {
        Ok(v) -> partition_map_loop(rest, categorise, [v, ..trues], falses)

        Error(Nil) ->
          partition_map_loop(rest, categorise, trues, [first, ..falses])
      }
  }
}
