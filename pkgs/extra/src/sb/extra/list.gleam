import gleam/list

pub fn deconstruct(list: List(a), empty: b, then: fn(a, List(a)) -> b) -> b {
  case list {
    [] -> empty
    [first, ..rest] -> then(first, rest)
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
