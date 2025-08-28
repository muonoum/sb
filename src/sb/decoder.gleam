import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/result
import gleam/set
import gleam/string
import sb/access.{type Access}
import sb/dots
import sb/error.{type Error}
import sb/extra
import sb/field
import sb/report.{type Report}
import sb/state.{type State}
import sb/task.{type Task, Task}
import sb/yaml

type Decoder(v) {
  Decoder(zero: v, decoder: fn(Dynamic) -> Result(v, Report(Error)))
}

fn run_decoder(
  dynamic: Dynamic,
  decoder: decode.Decoder(v),
) -> Result(v, Report(Error)) {
  decode.run(dynamic, decoder)
  |> report.map_error(error.DecodeError)
}

fn string_decoder() -> Decoder(String) {
  Decoder(zero: "", decoder: run_decoder(_, decode.string))
}

fn list_decoder(inner: decode.Decoder(v)) -> Decoder(List(v)) {
  Decoder(zero: [], decoder: run_decoder(_, decode.list(inner)))
}

fn optional_decoder(inner: decode.Decoder(v)) -> Decoder(Option(v)) {
  Decoder(zero: None, decoder: run_decoder(_, decode.map(inner, Some)))
}

fn access_decoder() -> Decoder(Access) {
  Decoder(zero: access.none(), decoder: access.decoder)
}

fn pairs_decoder(
  field_decoder: fn(Dynamic) -> Result(#(String, v), Report(Error)),
) -> Decoder(List(Result(#(String, v), Report(Error)))) {
  Decoder(zero: [], decoder: fn(dynamic) {
    use list <- result.map(run_decoder(dynamic, decode.list(decode.dynamic)))
    use <- extra.return(pair.second)
    use seen, dynamic <- list.map_fold(list, set.new())
    error.try_duplicate_ids(field_decoder(dynamic), seen)
  })
}

type Context =
  #(Dict(String, Dynamic), List(Report(Error)))

fn succeed(value: v) -> State(v, List(Report(Error)), Context) {
  use #(_, reports) <- state.do(state.get())
  use <- bool.guard(reports == [], state.succeed(value))
  state.fail(list.reverse(reports))
}

fn ok(
  result: Result(a, Report(Error)),
  then: fn(a) -> State(b, List(Report(Error)), Context),
) -> State(b, List(Report(Error)), Context) {
  state.do(then:, with: {
    case result {
      Ok(value) -> state.succeed(value)

      Error(report) -> {
        use #(_dict, reports) <- state.do(state.get())
        state.fail(list.reverse([report, ..reports]))
      }
    }
  })
}

fn decode_property(
  name: String,
  decoder: Decoder(v),
  default: fn() -> Result(v, Report(Error)),
) -> State(v, c, Context) {
  use #(dict, _) as context <- state.do(state.get())
  let Decoder(zero:, decoder:) = decoder

  let result = case dict.get(dict, name) {
    Error(Nil) -> default()

    Ok(dynamic) ->
      decoder(dynamic)
      |> report.error_context(error.BadProperty(name))
  }

  case result {
    Ok(value) -> state.succeed(value)

    Error(report) -> {
      let #(dict, reports) = context
      use <- state.then(state.put(#(dict, [report, ..reports])))
      state.succeed(zero)
    }
  }
}

fn load_properties(
  dynamic: Dynamic,
  then: fn() -> State(v, List(Report(Error)), Context),
) -> State(v, List(Report(Error)), Context) {
  use dict <- ok(
    decode.run(dynamic, decode.dict(decode.string, decode.dynamic))
    |> report.map_error(error.DecodeError)
    |> result.try(error.unknown_keys(_, [task_keys])),
  )

  use #(_dict, reports) <- state.do(state.get())
  use <- state.then(state.put(#(dict, reports)))
  then()
}

fn required(
  name: String,
  decoder: Decoder(a),
  then: fn(a) -> State(b, List(Report(Error)), Context),
) -> State(b, List(Report(Error)), Context) {
  state.do(then:, with: {
    use <- decode_property(name, decoder)
    report.error(error.MissingProperty(name))
  })
}

fn default(
  name: String,
  decoder: Decoder(a),
  default: Result(a, Report(Error)),
  then: fn(a) -> State(b, List(Report(Error)), Context),
) -> State(b, List(Report(Error)), Context) {
  lazy_default(name, decoder, fn() { default }, then)
}

fn lazy_default(
  name: String,
  decoder: Decoder(a),
  default: fn() -> Result(a, Report(Error)),
  then: fn(a) -> State(b, List(Report(Error)), Context),
) -> State(b, List(Report(Error)), Context) {
  state.do(then:, with: decode_property(name, decoder, default))
}

fn zero(
  name: String,
  decoder: Decoder(a),
  then: fn(a) -> State(b, List(Report(Error)), Context),
) -> State(b, List(Report(Error)), Context) {
  state.do(then:, with: {
    use <- decode_property(name, decoder)
    Ok(decoder.zero)
  })
}

const task_keys = [
  "id", "name", "category", "summary", "description", "command", "runners",
  "approvers", "layout", "summary_fields", "fields",
]

fn task_decoder(
  fields: Dict(String, Dict(String, Dynamic)),
  filters: Dict(String, Dict(String, Dynamic)),
) -> State(Task, List(Report(Error)), Context) {
  use name <- required("name", string_decoder())
  use category <- required("category", list_decoder(decode.string))
  use id <- default("id", string_decoder(), make_id(category, name))
  use summary <- zero("summary", optional_decoder(decode.string))
  use description <- zero("description", optional_decoder(decode.string))
  use command <- zero("command", list_decoder(decode.string))
  use runners <- zero("runners", access_decoder())
  use approvers <- zero("approvers", access_decoder())
  use fields <- zero("fields", pairs_decoder(field.decoder(_, fields, filters)))

  succeed(Task(
    id:,
    name:,
    category:,
    summary:,
    description:,
    command:,
    runners:,
    approvers:,
    layout: {
      use result <- list.map(fields)
      use #(id, _field) <- result.map(result)
      id
    },
    fields: dict.from_list({
      result.partition(fields)
      |> pair.first
    }),
  ))
}

const valid_id = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

fn make_id(category, name) {
  let category = string.join(list.map(category, into_id), "-")
  Ok(string.join([category, into_id(name)], "-"))
}

fn into_id(from: String) -> String {
  build_id(from, into: "")
}

fn build_id(from: String, into result: String) -> String {
  case string.pop_grapheme(from) {
    Error(Nil) -> result

    Ok(#(grapheme, rest)) -> {
      case string.contains(valid_id, grapheme) {
        True -> build_id(rest, result <> string.lowercase(grapheme))
        False -> build_id(rest, result <> "-")
      }
    }
  }
}

fn load_task(path: String) -> Dynamic {
  let assert Ok(dynamic) = yaml.decode_file(path)
  let assert Ok([doc, ..]) = decode.run(dynamic, decode.list(decode.dynamic))
  dots.split(doc)
}

pub fn main() {
  let dynamic = load_task("test_data/task1.yaml")

  echo state.run(with: #(dict.new(), []), state: {
    use <- load_properties(dynamic)
    task_decoder(dict.new(), dict.new())
  })
}
