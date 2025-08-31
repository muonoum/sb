import extra
import extra/dots
import extra/state.{type State}
import extra/yaml
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/pair
import gleam/result
import gleam/set
import gleam/string
import sb/access
import sb/error.{type Error}
import sb/field
import sb/props
import sb/report.{type Report}
import sb/task.{type Task, Task}

pub fn main() {
  let dynamic = load_task("test_data/task1.yaml")
  let decoder = task_decoder(dict.new(), dict.new())
  echo props.decode(dynamic, task_keys, decoder)
}

fn load_task(path: String) -> Dynamic {
  let assert Ok(dynamic) = yaml.decode_file(path)
  let assert Ok([doc, ..]) = decode.run(dynamic, decode.list(decode.dynamic))
  dots.split(doc)
}

const task_keys = [
  "id", "name", "category", "summary", "description", "command", "runners",
  "approvers", "layout", "summary_fields", "fields",
]

pub const access_keys = ["users", "groups", "keys"]

fn task_decoder(
  fields: Dict(String, Dict(String, Dynamic)),
  filters: Dict(String, Dict(String, Dynamic)),
) -> State(Task, List(Report(Error)), props.Context) {
  use name <- props.required("name", props.string())
  use category <- props.required("category", props.list(props.string()))
  use id <- props.default("id", props.string(), make_id(category, name))
  use summary <- props.zero("summary", props.optional(props.string()))
  use description <- props.zero("description", props.optional(props.string()))
  use command <- props.zero("command", props.list(props.string()))
  use runners <- props.zero("runners", access.access_dekoder())
  use approvers <- props.zero("approvers", access.access_dekoder())

  // use fields <- props.zero(
  //   "fields",
  //   props.list(
  //     props.Decoder(zero: [], decode: fn(dynamic) {
  //       field.decoder(dynamic, fields, filters)
  //     }),
  //   ),
  // )

  use fields <- props.zero(
    "fields",
    props.Decoder(zero: [], decode: fn(dynamic) {
      use list <- result.map({
        props.run_decoder(dynamic, decode.list(decode.dynamic))
      })

      use <- extra.return(pair.second)
      use seen, dynamic <- list.map_fold(list, set.new())
      field.decoder(dynamic, fields, filters)
      |> error.try_duplicate_ids(seen)
    }),
  )

  props.succeed(Task(
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
