import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder}
import gleam/list
import gleam/option
import gleam/pair
import gleam/result
import gleam/set
import gleam/string
import sb/access
import sb/dots
import sb/error.{type Error}
import sb/extra
import sb/field
import sb/report.{type Report}
import sb/state.{type State}
import sb/task.{type Task, Task}
import sb/yaml

type Context =
  #(Dict(String, Dynamic), List(Report(Error)))

fn decode(dynamic: Dynamic, decoder: Decoder(v)) -> Result(v, Report(Error)) {
  decode.run(dynamic, decoder)
  |> report.map_error(error.DecodeError)
}

fn succeed(value: v) -> State(v, List(Report(Error)), Context) {
  use #(_, reports) <- state.do(state.get())
  use <- bool.guard(reports == [], state.succeed(value))
  state.fail(list.reverse(reports))
}

fn fail(
  report: Report(Error),
  zero: v,
  context: Context,
) -> State(v, e, Context) {
  let #(dict, reports) = context
  use <- state.then(state.put(#(dict, [report, ..reports])))
  state.succeed(zero)
}

fn unwrap(
  error: Error,
  fail: fn(Report(Error)) -> State(v, e, c),
  result: Result(v, Report(Error)),
) -> State(v, e, c) {
  case result {
    Error(report) -> fail(report.context(report, error))
    Ok(value) -> state.succeed(value)
  }
}

fn decode_dict(
  decode: Result(Dict(String, Dynamic), Report(Error)),
  then: fn() -> State(v, List(Report(Error)), Context),
) -> State(v, List(Report(Error)), Context) {
  use dict <- ok(decode)
  use #(_dict, reports) <- state.do(state.get())
  use <- state.then(state.put(#(dict, reports)))
  then()
}

fn ok(
  result: Result(a, Report(Error)),
  then: fn(a) -> State(b, List(Report(Error)), Context),
) -> State(b, List(Report(Error)), Context) {
  state.do(then:, with: {
    use #(_dict, reports) <- state.do(state.get())

    case result {
      Error(report) -> state.fail(list.reverse([report, ..reports]))
      Ok(value) -> state.succeed(value)
    }
  })
}

fn required(
  name: String,
  zero: a,
  decoder: fn(Dynamic) -> Result(a, Report(Error)),
  then: fn(a) -> State(b, List(Report(Error)), Context),
) -> State(b, List(Report(Error)), Context) {
  state.do(then:, with: {
    use #(dict, _) as context <- state.do(state.get())
    let fail = fail(_, zero, context)

    case dict.get(dict, name) {
      Error(Nil) -> fail(report.new(error.MissingProperty(name)))
      Ok(dynamic) -> unwrap(error.BadProperty(name), fail, decoder(dynamic))
    }
  })
}

fn default(
  name: String,
  zero: a,
  decoder: fn(Dynamic) -> Result(a, Report(Error)),
  default: fn() -> Result(a, Report(Error)),
  then: fn(a) -> State(b, List(Report(Error)), Context),
) -> State(b, List(Report(Error)), Context) {
  state.do(then:, with: {
    use #(dict, _) as context <- state.do(state.get())
    let fail = fail(_, zero, context)

    unwrap(error.BadProperty(name), fail, {
      case dict.get(dict, name) {
        Error(Nil) -> default()
        Ok(dynamic) -> decoder(dynamic)
      }
    })
  })
}

fn zero(
  name: String,
  zero: a,
  decoder: fn(Dynamic) -> Result(a, Report(Error)),
  then: fn(a) -> State(b, List(Report(Error)), Context),
) -> State(b, List(Report(Error)), Context) {
  state.do(then:, with: {
    use #(dict, _) as context <- state.do(state.get())
    let fail = fail(_, zero, context)

    unwrap(error.BadProperty(name), fail, {
      case dict.get(dict, name) {
        Error(Nil) -> Ok(zero)
        Ok(dynamic) -> decoder(dynamic)
      }
    })
  })
}

const task_keys = [
  "id", "name", "category", "summary", "description", "command", "runners",
  "approvers", "layout", "summary_fields", "fields",
]

fn task_decoder(
  dynamic: Dynamic,
  fields: Dict(String, Dict(String, Dynamic)),
  filters: Dict(String, Dict(String, Dynamic)),
) -> State(Task, List(Report(Error)), Context) {
  use <- decode_dict({
    decode.run(dynamic, decode.dict(decode.string, decode.dynamic))
    |> report.map_error(error.DecodeError)
    |> result.try(error.unknown_keys(_, [task_keys]))
  })

  use name <- required("name", "", decode(_, decode.string))
  use category <- required("category", [], decode(_, decode.list(decode.string)))

  use id <- default("id", "", decode(_, decode.string), fn() {
    let category = string.join(list.map(category, into_id), "-")
    Ok(string.join([category, into_id(name)], "-"))
  })

  use summary <- zero("summary", option.None, {
    decode(_, decode.map(decode.string, option.Some))
  })

  use description <- zero("description", option.None, {
    decode(_, decode.map(decode.string, option.Some))
  })

  use command <- zero("command", [], decode(_, decode.list(decode.string)))
  use runners <- zero("runners", access.none(), access.decoder)
  use approvers <- zero("approvers", access.none(), access.decoder)

  use fields <- zero("fields", [], fn(dynamic) {
    use list <- result.map(decode(dynamic, decode.list(decode.dynamic)))
    use <- extra.return(pair.second)
    use seen, dynamic <- list.map_fold(list, set.new())
    field.decoder(dynamic, fields, filters)
    |> error.try_duplicate_ids(seen)
  })

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
  let decoder = task_decoder(dynamic, dict.new(), dict.new())
  let context = #(dict.new(), [])
  state.run(decoder, context) |> echo
}
