import extra
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/pair
import gleam/string

pub fn split(data: Dynamic) -> Dynamic {
  case decode_list(data) {
    Ok(values) -> extra.dynamic_from(list.map(values, split))

    Error(..) ->
      case decode_dict(data) {
        Error(..) -> data

        Ok(values) ->
          dict.to_list(values)
          |> list.map(split_node)
          |> list.filter_map(decode_dict)
          |> list.fold(dict.new(), merge_dicts)
          |> extra.dynamic_from
      }
  }
}

fn decode_list(
  dynamic: Dynamic,
) -> Result(List(Dynamic), List(decode.DecodeError)) {
  decode.run(dynamic, decode.list(decode.dynamic))
}

fn decode_dict(
  dynamic: Dynamic,
) -> Result(Dict(String, Dynamic), List(decode.DecodeError)) {
  decode.run(dynamic, decode.dict(decode.string, decode.dynamic))
}

fn merge_dicts(
  a: Dict(String, Dynamic),
  b: Dict(String, Dynamic),
) -> Dict(String, Dynamic) {
  use a, b <- dict.combine(a, b)
  case decode_dict(a), decode_dict(b) {
    Ok(a), Ok(b) -> extra.dynamic_from(merge_dicts(a, b))
    _other, _wise -> b
  }
}

fn split_node(node: #(String, Dynamic)) -> Dynamic {
  let #(key, value) = pair.map_second(node, split)
  let list = list.reverse(string.split(key, on: "."))
  use value, key <- list.fold(list, value)
  extra.dynamic_from(dict.from_list([#(key, value)]))
}
