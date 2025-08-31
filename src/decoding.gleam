import extra
import extra/dots
import extra/state
import extra/yaml
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/http
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
import sb/inspect
import sb/kind.{type Kind}
import sb/options.{type Options}
import sb/props.{type Props}
import sb/report.{type Report}
import sb/reset.{type Reset}
import sb/source.{type Source}
import sb/task.{type Task, Task}
import sb/text
import sb/value

type Custom =
  Dict(String, Dynamic)

type Fields {
  Fields(custom: Dict(String, Custom))
}

type Filters {
  Filters(custom: Dict(String, Custom))
}

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

  let custom_fields =
    Fields(
      dict.from_list([
        #(
          "mega",
          dict.from_list([
            #("kind", dynamic.string("data")),
            #(
              "source",
              dynamic.properties([
                #(dynamic.string("reference"), dynamic.string("a")),
              ]),
            ),
          ]),
        ),
      ]),
    )

  let custom_filters = Filters(dict.new())

  let decoder = task_decoder(custom_fields, custom_filters)
  let assert Ok(task) = props.decode(dynamic, decoder)
  inspect.inspect_task(echo task)
}

fn load_task(path: String) -> Dynamic {
  let assert Ok(dynamic) = yaml.decode_file(path)
  let assert Ok([doc, ..]) = decode.run(dynamic, decode.list(decode.dynamic))
  dots.split(doc)
}

// TASK

fn task_decoder(fields: Fields, filters: Filters) -> Props(Task) {
  use <- state.do(props.check_unknown_keys(task_keys))

  use name <- props.field("name", props.run_decoder(decode.string))

  use category <- props.field("category", {
    props.run_decoder(decode.list(decode.string))
  })

  use id <- props.default_field("id", make_id(category, name), {
    props.run_decoder(decode.string)
  })

  use summary <- props.default_field("summary", Ok(None), {
    props.run_decoder(decode.map(decode.string, Some))
  })

  use description <- props.default_field("description", Ok(None), {
    props.run_decoder(decode.map(decode.string, Some))
  })

  use command <- props.default_field("command", Ok([]), {
    props.run_decoder(decode.list(decode.string))
  })

  use runners <- props.default_field("runners", Ok(access.none()), {
    props.decode(_, access_decoder())
  })

  use approvers <- props.default_field("approvers", Ok(access.none()), {
    props.decode(_, access_decoder())
  })

  use fields <- props.default_field("fields", Ok([]), fn(dynamic) {
    let list_decoder = props.run_decoder(decode.list(decode.dynamic))
    use list <- result.map(list_decoder(dynamic))
    use <- extra.return(pair.second)
    use seen, dynamic <- list.map_fold(list, set.new())
    props.decode(dynamic, field_decoder(fields, filters))
    |> error.try_duplicate_ids(seen)
  })

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

// ACCESS

pub fn access_decoder() -> Props(Access) {
  use <- state.do(props.check_unknown_keys(access_keys))

  use users <- props.default_field("users", Ok(access.Users([])), {
    props.run_decoder(users_decoder())
  })

  use groups <- props.default_field("groups", Ok([]), {
    props.run_decoder(decode.list(decode.string))
  })

  use keys <- props.default_field("keys", Ok([]), {
    props.run_decoder(decode.list(decode.string))
  })

  props.succeed(access.Access(users:, groups:, keys:))
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

// FIELD

fn field_decoder(fields: Fields, _filters: Filters) -> Props(#(String, Field)) {
  use id <- props.field("id", props.run_decoder(decode.string))

  use <- extra.return(
    state.map_error(_, report.context(_, error.FieldContext(id))),
  )

  use kind <- state.with(kind_decoder(fields))

  use label <- props.default_field("label", Ok(None), {
    props.run_decoder(decode.map(decode.string, Some))
  })

  use description <- props.default_field("description", Ok(None), {
    props.run_decoder(decode.map(decode.string, Some))
  })

  use disabled <- props.default_field(
    "disabled",
    Ok(condition.false()),
    condition.decoder,
  )

  use hidden <- props.default_field(
    "hidden",
    Ok(condition.false()),
    condition_decoder,
  )

  use ignored <- props.default_field(
    "ignored",
    Ok(condition.false()),
    condition_decoder,
  )

  use optional <- props.default_field(
    "optional",
    Ok(condition.false()),
    condition_decoder,
  )

  props.succeed(#(
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

// CONDITION

fn condition_decoder(dynamic) {
  case decode.run(dynamic, decode.bool) {
    Ok(bool) -> Ok(condition.resolved(bool))
    Error(..) -> props.decode(dynamic, condition_kind_decoder())
  }
}

fn condition_kind_decoder() -> Props(Condition) {
  use dict <- state.with(state.get())

  case dict.to_list(dict) {
    [#("when", _dynamic)] -> todo as "when condition"
    [#("unless", _dynamic)] -> todo as "unless condition"
    [#(_unknown, _)] -> todo as "unknown condition"
    _bad -> todo as "bad condition"
  }
}

// KIND

fn kind_decoder(fields: Fields) -> Props(Kind) {
  use kind <- props.field("kind", props.run_decoder(decode.string))

  case dict.get(fields.custom, kind) {
    Ok(custom) -> {
      use <- state.do(state.update(dict.merge(_, custom)))
      kind_decoder(fields)
    }

    Error(Nil) -> {
      use <- state.do(
        state.from_result(kind.keys(kind))
        |> state.map(list.append(field_keys, _))
        |> state.try(props.check_unknown_keys),
      )

      case kind {
        "data" -> data_decoder()
        "text" -> text_decoder()
        "textarea" -> textarea_decoder()
        "radio" -> radio_decoder()
        "checkbox" -> checkbox_decoder()
        "select" -> select_decoder()
        unknown -> props.fail(report.new(error.UnknownKind(unknown)))
      }
    }
  }
}

fn data_decoder() -> Props(Kind) {
  // use source <- props.field("source", props.decode(_, source_decoder()))
  // let reset = reset.try_new(Ok(source), source.refs)
  use source <- props.field("source", props.decode(_, source_decoder()))
  // let reset = reset.try_new(Ok(source), source.refs)
  // props.succeed(kind.Data(reset))
  props.succeed(kind.Data(source))
}

fn text_decoder() -> Props(Kind) {
  props.succeed(kind.Text(""))
}

fn textarea_decoder() -> Props(Kind) {
  props.succeed(kind.Textarea(""))
}

fn radio_decoder() -> Props(Kind) {
  use options <- props.field("source", props.decode(_, options_decoder()))
  props.succeed(kind.Select(None, options:))
}

fn checkbox_decoder() -> Props(Kind) {
  use options <- props.field("source", props.decode(_, options_decoder()))
  props.succeed(kind.MultiSelect([], options:))
}

fn select_decoder() -> Props(Kind) {
  use multiple <- props.default_field("multiple", Ok(False), {
    props.run_decoder(decode.bool)
  })

  use options <- props.field("source", props.decode(_, options_decoder()))
  use <- bool.guard(multiple, props.succeed(kind.MultiSelect([], options:)))
  props.succeed(kind.Select(None, options:))
}

// SOURCE

fn source_decoder() -> Props(Reset(Result(Source, Report(Error)))) {
  use dict <- state.with(state.get())
  use <- extra.return(state.succeed)
  use <- extra.return(reset.try_new(_, source.refs))

  case dict.to_list(dict) {
    [#("literal", dynamic)] -> literal_decoder(dynamic)
    [#("reference", dynamic)] -> reference_decoder(dynamic)
    [#("template", dynamic)] -> template_decoder(dynamic)
    [#("command", dynamic)] -> command_decoder(dynamic)
    [#("fetch", dynamic)] -> fetch_decoder(dynamic)
    [#(name, _)] -> report.error(error.UnknownKind(name))
    _bad -> report.error(error.BadSource)
  }
}

fn literal_decoder(dynamic: Dynamic) -> Result(Source, Report(Error)) {
  dynamic
  |> props.run_decoder(value.decoder())
  |> report.error_context(error.BadKind("literal"))
  |> result.map(source.Literal)
}

fn reference_decoder(dynamic: Dynamic) -> Result(Source, Report(Error)) {
  use <- report.with_error_context(error.BadKind("reference"))

  dynamic
  |> props.run_decoder(decode.string)
  |> result.map(source.Reference)
}

fn template_decoder(dynamic: Dynamic) -> Result(Source, Report(Error)) {
  use <- report.with_error_context(error.BadKind("template"))

  text.decoder(dynamic)
  |> result.map(source.Template)
}

fn command_decoder(_dynamic: Dynamic) -> Result(Source, Report(Error)) {
  todo as "decode command"
}

fn fetch_decoder(dynamic: Dynamic) -> Result(Source, Report(Error)) {
  use <- report.with_error_context(error.BadKind("fetch"))

  case dynamic |> decode.run(decode.dict(decode.string, decode.dynamic)) {
    Error(..) -> {
      use uri <- result.try(
        text.decoder(dynamic)
        |> report.error_context(error.BadProperty("url")),
      )

      Ok(source.Fetch(
        method: http.Get,
        uri: uri,
        headers: [],
        body: option.None,
      ))
    }

    Ok(dict) -> {
      use uri <- result.try({
        dict.get(dict, "url")
        |> report.replace_error(error.MissingProperty("url"))
        |> result.try(fn(dynamic) {
          text.decoder(dynamic)
          |> report.error_context(error.BadProperty("url"))
        })
      })

      // TODO
      use _body <- result.try({
        case dict.get(dict, "body") {
          Error(Nil) -> Ok(option.None)

          Ok(dynamic) ->
            props.decode(dynamic, source_decoder())
            |> report.error_context(error.BadProperty("url"))
            |> result.map(option.Some)
        }
      })

      use method <- result.try({
        case dict.get(dict, "method") {
          Error(Nil) -> Ok(http.Get)

          Ok(dynamic) ->
            decode.run(dynamic, decode.string)
            |> report.map_error(error.DecodeError)
            |> report.error_context(error.BadProperty("method"))
            |> result.map(string.uppercase)
            |> result.try(fn(string) {
              http.parse_method(string)
              |> report.replace_error(error.BadProperty("method"))
            })
        }
      })

      use headers <- result.try({
        case dict.get(dict, "headers") {
          Error(Nil) -> Ok([])

          Ok(dynamic) ->
            dynamic
            |> decode.run(decode.dict(decode.string, decode.string))
            |> report.map_error(error.DecodeError)
            |> report.error_context(error.BadProperty("headers"))
            |> result.map(dict.to_list)
        }
      })

      // TODO
      // Ok(source.Fetch(method:, uri:, headers:, body:))
      Ok(source.Fetch(method:, uri:, headers:, body: None))
    }
  }
}

// OPTIONS

fn options_decoder() -> Props(Options) {
  use dict <- state.with(state.get())

  case dict.to_list(dict) {
    [#("groups", _dynamic)] -> todo as "source groups"
    _else -> state.map(source_decoder(), options.SingleSource)
  }
}
