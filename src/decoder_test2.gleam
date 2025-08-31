import extra
import extra/dots
import extra/state
import extra/yaml
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{None, Some}
import gleam/pair
import gleam/result
import gleam/set
import gleam/string
import sb/access.{type Access}
import sb/condition.{type Condition}
import sb/error.{type Error}
import sb/field.{type Field, Field}
import sb/kind.{type Kind}
import sb/options
import sb/report.{type Report}
import sb/reset
import sb/source
import sb/task.{type Task, Task}

type State(v) =
  state.State(v, Report(Error), Dict(String, Dynamic))

type Decoder(v) =
  fn(Dynamic) -> Result(v, Report(Error))

const task_keys = [
  "id", "name", "category", "summary", "description", "command", "runners",
  "approvers", "layout", "summary_fields", "fields",
]

const access_keys = ["users", "groups", "keys"]

const field_keys = [
  "id", "kind", "label", "description", "disabled", "hidden", "ignored",
  "optional", "filters",
]

pub fn main() {
  let dynamic = load_task("test_data/task1.yaml")
  let decoder = task_decoder(dict.new(), dict.new())
  echo decode_dict(dynamic, decoder)
}

fn load_task(path: String) -> Dynamic {
  let assert Ok(dynamic) = yaml.decode_file(path)
  let assert Ok([doc, ..]) = decode.run(dynamic, decode.list(decode.dynamic))
  dots.split(doc)
}

fn from_result(result: Result(v, Report(Error))) -> State(v) {
  case result {
    Error(error) -> state.fail(error)
    Ok(value) -> state.succeed(value)
  }
}

fn check_keys(keys: List(String)) -> State(Nil) {
  use dict <- state.with(state.get())

  case error.unknown_keys(dict, keys) {
    Error(report) -> state.fail(report)
    Ok(_dict) -> state.succeed(Nil)
  }
}

fn task_decoder(
  fields: Dict(String, Dict(String, Dynamic)),
  filters: Dict(String, Dict(String, Dynamic)),
) -> State(Task) {
  use <- state.do(check_keys(task_keys))

  use name <- decode_field("name", decode_run(decode.string))

  use category <- decode_field("category", {
    decode_run(decode.list(decode.string))
  })

  use id <- decode_default_field("id", make_id(category, name), {
    decode_run(decode.string)
  })

  use summary <- decode_default_field("summary", Ok(None), {
    decode_run(decode.map(decode.string, Some))
  })

  use description <- decode_default_field("description", Ok(None), {
    decode_run(decode.map(decode.string, Some))
  })

  use command <- decode_default_field("command", Ok([]), {
    decode_run(decode.list(decode.string))
  })

  use runners <- decode_default_field("runners", Ok(access.none()), {
    decode_dict(_, access_decoder())
  })

  use approvers <- decode_default_field("approvers", Ok(access.none()), {
    decode_dict(_, access_decoder())
  })

  use fields <- decode_default_field("fields", Ok([]), fn(dynamic) {
    let list_decoder = decode_run(decode.list(decode.dynamic))
    use list <- result.map(list_decoder(dynamic))
    use <- extra.return(pair.second)
    use seen, dynamic <- list.map_fold(list, set.new())
    decode_dict(dynamic, field_decoder(fields, filters))
    |> error.try_duplicate_ids(seen)
  })

  decode_succeed(Task(
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

pub fn access_decoder() -> State(Access) {
  use <- state.do(check_keys(access_keys))

  use users <- decode_default_field("users", Ok(access.Users([])), {
    decode_run(users_decoder())
  })

  use groups <- decode_default_field("groups", Ok([]), {
    decode_run(decode.list(decode.string))
  })

  use keys <- decode_default_field("keys", Ok([]), {
    decode_run(decode.list(decode.string))
  })

  decode_succeed(access.Access(users:, groups:, keys:))
}

fn users_decoder() -> decode.Decoder(access.Users) {
  decode.one_of(decode.then(decode.string, user_decoder), [
    decode.list(decode.string) |> decode.map(access.Users),
  ])
}

fn user_decoder(string: String) -> decode.Decoder(access.Users) {
  case string {
    "everyone" -> decode.success(access.Everyone)
    _string -> decode.failure(access.Everyone, "'everyone' or a list of users")
  }
}

fn kind_decoder(fields: Dict(String, Dict(String, Dynamic))) -> State(Kind) {
  use kind <- decode_field("kind", decode_run(decode.string))

  case dict.get(fields, kind) {
    Ok(custom) -> {
      use <- state.do(state.update(dict.merge(_, custom)))
      kind_decoder(fields)
    }

    Error(Nil) -> {
      use <- state.do(
        from_result(kind.keys(kind))
        |> state.map(list.append(field_keys, _))
        |> state.try(check_keys),
      )

      case kind {
        "data" -> data_decoder()
        "text" -> text_decoder()
        "textarea" -> textarea_decoder()
        "radio" -> radio_decoder()
        "checkbox" -> checkbox_decoder()
        "select" -> select_decoder()
        unknown -> state.fail(report.new(error.UnknownKind(unknown)))
      }
    }
  }
}

fn data_decoder() -> State(Kind) {
  use source <- decode_field("source", source.decoder)
  let reset = reset.try_new(Ok(source), source.refs)
  decode_succeed(kind.Data(reset))
}

fn text_decoder() -> State(Kind) {
  decode_succeed(kind.Text(""))
}

fn textarea_decoder() -> State(Kind) {
  decode_succeed(kind.Textarea(""))
}

fn radio_decoder() -> State(Kind) {
  use options <- decode_field("source", options.decoder)
  decode_succeed(kind.Select(None, options:))
}

fn checkbox_decoder() -> State(Kind) {
  use options <- decode_field("source", options.decoder)
  decode_succeed(kind.MultiSelect([], options:))
}

fn select_decoder() -> State(Kind) {
  use multiple <- decode_default_field("multiple", Ok(False), {
    decode_run(decode.bool)
  })

  use options <- decode_field("source", options.decoder)
  use <- bool.guard(multiple, decode_succeed(kind.MultiSelect([], options:)))
  decode_succeed(kind.Select(None, options:))
}

fn field_decoder(
  fields: Dict(String, Dict(String, Dynamic)),
  _filters: Dict(String, Dict(String, Dynamic)),
) -> State(#(String, Field)) {
  use id <- decode_field("id", decode_run(decode.string))

  use <- extra.return(
    state.map_error(_, report.context(_, error.FieldContext(id))),
  )

  use kind <- state.with(kind_decoder(fields))

  use label <- decode_default_field("label", Ok(None), {
    decode_run(decode.map(decode.string, Some))
  })

  use description <- decode_default_field("description", Ok(None), {
    decode_run(decode.map(decode.string, Some))
  })

  use disabled <- decode_default_field(
    "disabled",
    Ok(condition.false()),
    condition.decoder,
  )

  use hidden <- decode_default_field(
    "hidden",
    Ok(condition.false()),
    condition_decoder,
  )

  use ignored <- decode_default_field(
    "ignored",
    Ok(condition.false()),
    condition_decoder,
  )

  use optional <- decode_default_field(
    "optional",
    Ok(condition.false()),
    condition_decoder,
  )

  decode_succeed(#(
    id,
    Field(
      kind:,
      label:,
      description:,
      disabled: reset.new(disabled, condition.refs),
      hidden: reset.new(hidden, condition.refs),
      ignored: reset.new(ignored, condition.refs),
      optional: reset.new(optional, condition.refs),
      filters: [],
    ),
  ))
}

fn condition_decoder(dynamic) {
  case decode.run(dynamic, decode.bool) {
    Ok(bool) -> Ok(condition.resolved(bool))
    Error(..) -> decode_dict(dynamic, condition_kind_decoder())
  }
}

fn condition_kind_decoder() -> State(Condition) {
  use dict <- state.with(state.get())

  case dict.to_list(dict) {
    [#("when", _dynamic)] -> state.succeed(condition.false())
    [#("unless", _dynamic)] -> state.succeed(condition.false())
    [#(_unknown, _)] -> todo
    _bad -> todo
  }
}

fn decode_run(
  decoder: decode.Decoder(v),
) -> fn(Dynamic) -> Result(v, Report(Error)) {
  fn(dynamic) {
    decode.run(dynamic, decoder)
    |> report.map_error(error.DecodeError)
  }
}

fn decode_dict(dynamic: Dynamic, decoder: State(v)) -> Result(v, Report(Error)) {
  state.run(context: dict.new(), state: {
    use <- load_dict(dynamic)
    decoder
  })
}

// fn decode_list(
//   decoder: Decoder(v),
// ) -> fn(Dynamic) -> Result(List(v), Report(Error)) {
//   fn(dynamic) {
//     decode_run(dynamic, decode.list(decode.dynamic))
//     |> result.try(list.try_map(_, decoder))
//   }
// }

fn load_dict(dynamic: Dynamic, next: fn() -> State(v)) -> State(v) {
  let decoder = decode_run(decode.dict(decode.string, decode.dynamic))

  case decoder(dynamic) {
    Error(report) -> state.fail(report)
    Ok(dict) -> state.do(state.put(dict), next)
  }
}

fn decode_succeed(value: v) -> State(v) {
  state.succeed(value)
}

fn decode_field(
  name: String,
  decoder: Decoder(a),
  next: fn(a) -> State(b),
) -> State(b) {
  let error = report.error(error.MissingProperty(name))
  decode_default_field(name, error, decoder, next)
}

fn decode_default_field(
  name: String,
  default: Result(a, Report(Error)),
  decoder: Decoder(a),
  next: fn(a) -> State(b),
) -> State(b) {
  use dict <- state.with(state.get())

  let result = case dict.get(dict, name) {
    Error(Nil) -> default

    Ok(dynamic) ->
      decoder(dynamic)
      |> report.error_context(error.BadProperty(name))
  }

  case result {
    Error(report) -> state.fail(report)
    Ok(value) -> state.with(state.succeed(value), next)
  }
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
