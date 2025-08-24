import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set
import sb/error.{type Error}
import sb/report.{type Report}

pub type Decoder(v) =
  decode.Decoder(v)

pub const run = decode.run

pub const succeed = decode.success

pub const fail = decode.failure

pub const one_of = decode.one_of

pub const then = decode.then

pub const int = decode.int

pub const string = decode.string

pub const list = decode.list

pub const dynamic = decode.dynamic

pub const map = decode.map

pub fn try(
  dict: Dict(String, Dynamic),
  name: String,
  decoder: Decoder(v),
  or: fn() -> Result(v, Report(Error)),
) -> Result(v, Report(Error)) {
  case dict.get(dict, name) {
    Error(Nil) -> or()

    Ok(dynamic) ->
      decode.run(dynamic, decoder)
      |> report.map_error(error.DecodeError)
      |> report.error_context(error.BadProperty(name))
  }
}

pub fn try2(
  value: Result(Dynamic, Nil),
  decoder: Decoder(v),
  or: fn() -> Result(v, Report(Error)),
) -> Result(v, Report(Error)) {
  case value {
    Error(Nil) -> or()

    Ok(dynamic) ->
      decode.run(dynamic, decoder)
      |> report.map_error(error.DecodeError)
  }
}

pub fn try_dynamic(
  dict: Dict(String, Dynamic),
  name: String,
  decoder: fn(Dynamic) -> Result(v, Report(Error)),
  then: fn() -> Result(v, Report(Error)),
) -> Result(v, Report(Error)) {
  case dict.get(dict, name) {
    Error(Nil) -> then()

    Ok(dynamic) ->
      decoder(dynamic)
      |> report.error_context(error.BadProperty(name))
  }
}

pub fn required(
  dict: Dict(String, Dynamic),
  name: String,
  decoder: Decoder(v),
) -> Result(v, Report(Error)) {
  use <- try(dict, name, decoder)
  report.error(error.MissingProperty(name))
}

pub fn optional(
  dict: Dict(String, Dynamic),
  name: String,
  decoder: Decoder(v),
) -> Result(Option(v), Report(Error)) {
  use <- try(dict, name, decode.map(decoder, Some))
  Ok(None)
}

pub fn known_dict(
  dynamic: Dynamic,
  known_keys: List(List(String)),
) -> Result(Dict(String, Dynamic), Report(Error)) {
  decode.run(dynamic, decode.dict(decode.string, decode.dynamic))
  |> report.map_error(error.DecodeError)
  |> result.try(unknown_keys(_, known_keys))
}

fn unknown_keys(
  dict: Dict(String, v),
  known_keys: List(List(String)),
) -> Result(Dict(String, v), Report(Error)) {
  let known_keys =
    list.map(known_keys, set.from_list)
    |> list.fold(set.new(), set.union)

  let unknown_keys =
    set.from_list(dict.keys(dict))
    |> set.difference(known_keys)
    |> set.to_list

  case unknown_keys {
    [] -> Ok(dict)
    keys -> report.error(error.UnknownKeys(keys))
  }
}
