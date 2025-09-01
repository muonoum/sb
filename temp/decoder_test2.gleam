import extra/dots
import extra/yaml
import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/pair
import gleam/result
import gleam/string
import sb/task.{Task}

const task_keys = [
  "id", "name", "category", "summary", "description", "command", "runners",
  "approvers", "layout", "summary_fields", "fields",
]

pub fn main() {
  let dynamic = load_task("test_data/task1.yaml")
  let decoder = task_decoder(dict.new(), dict.new())
  echo decode(dynamic, [task_keys], decoder)
}

fn load_task(path: String) -> Dynamic {
  let assert Ok(dynamic) = yaml.decode_file(path)
  let assert Ok([doc, ..]) = decode.run(dynamic, decode.list(decode.dynamic))
  dots.split(doc)
}

pub fn decode(_dynamic, _keys, _decoder) {
  todo
}

pub fn task_decoder(_fields, _filters) {
  let optional_string = optional_decoder(string_decoder())
  let string_list = list_decoder(string_decoder())

  use name <- required_field("name", string_decoder())
  use category <- required_field("category", string_list)
  use id <- optional_default("id", string_decoder(), make_id(category, name))
  use summary <- optional_zero("summary", optional_string)
  use description <- optional_zero("description", optional_string)
  use command <- optional_zero("command", string_list)
  use runners <- optional_zero("runners", access_decoder())
  use approvers <- optional_zero("approvers", access_decoder())
  use fields <- optional_zero("fields", pairs_decoder(field_decoder()))

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

fn succeed(_value) {
  todo
}

fn field_decoder() {
  todo
}

fn access_decoder() {
  todo
}

fn required_field(_key, _decoder, _then) {
  todo
}

fn optional_zero(_key, _decoder, _then) {
  todo
}

fn optional_default(_key, _decoder, _default, _then) {
  todo
}

fn string_decoder() {
  todo
}

fn optional_decoder(_inner) {
  todo
}

fn list_decoder(_inner) {
  todo
}

fn pairs_decoder(_value_decoder) {
  todo
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
