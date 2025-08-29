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
import gleam/string
import sb/access
import sb/condition
import sb/dekode
import sb/error.{type Error}
import sb/field.{Field}
import sb/kind
import sb/props
import sb/report.{type Report}
import sb/reset
import sb/task.{type Task, Task}
import sb/value

pub fn main() {
  let dynamic = load_task("test_data/task1.yaml")
  let decoder = task_decoder(dict.new(), dict.new())
  echo props.decode(dynamic, [task_keys], decoder)
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

fn access_decoder() -> dekode.Decoder(access.Access) {
  dekode.Decoder(zero: access.none(), decoder: fn(dynamic) {
    use <- extra.return(report.map_error(_, error.Collected))

    props.decode(dynamic, [access_keys], {
      use users <- props.zero("users", users_decoder())
      use groups <- props.zero("groups", dekode.list(decode.string))
      use keys <- props.zero("key", dekode.list(decode.string))
      dekode.succeed(access.Access(users:, groups:, keys:))
    })
  })
}

fn users_decoder() -> dekode.Decoder(access.Users) {
  dekode.Decoder(
    zero: access.Everyone,
    decoder: dekode.std_decoder(
      decode.one_of(decode.then(decode.string, user_decoder), [
        decode.list(decode.string) |> decode.map(access.Users),
      ]),
    ),
  )
}

fn user_decoder(string: String) -> decode.Decoder(access.Users) {
  case string {
    "everyone" -> decode.success(access.Everyone)
    _string -> decode.failure(access.Everyone, "'everyone' or a list of users")
  }
}

fn field_decoder() {
  use id <- props.required("id", dekode.string())
  use label <- props.zero("label", dekode.optional(decode.string))
  use description <- props.zero("description", dekode.optional(decode.string))

  use disabled <- props.zero("disabled", condition_decoder())
  use hidden <- props.zero("hidden", condition_decoder())
  use ignored <- props.zero("ignored", condition_decoder())
  use optional <- props.zero("optional", condition_decoder())

  let field =
    Field(
      kind: kind.Text(""),
      label:,
      description:,
      disabled: reset.new(disabled, condition.refs),
      hidden: reset.new(hidden, condition.refs),
      ignored: reset.new(ignored, condition.refs),
      optional: reset.new(optional, condition.refs),
      filters: [],
    )

  dekode.succeed(#(id, field))
}

fn condition_decoder() -> dekode.Decoder(condition.Condition) {
  dekode.Decoder(zero: condition.false(), decoder: fn(dynamic) {
    use <- extra.return(report.map_error(_, error.Collected))

    case decode.run(dynamic, decode.bool) {
      Ok(bool) -> Ok(condition.resolved(bool))

      Error(_) ->
        props.decode(dynamic, [["when", "unless"]], {
          use dict <- props.get()

          case dict.to_list(dict) {
            [#("when", dynamic)] ->
              case decode.run(dynamic, decode.string) {
                Ok(id) -> dekode.succeed(condition.defined(id))
                Error(_) -> {
                  let dict =
                    decode.run(
                      dynamic,
                      decode.dict(decode.string, decode.dynamic),
                    )

                  case result.map(dict, dict.to_list) {
                    Ok([#(id, dynamic)]) ->
                      case decode.run(dynamic, value.decoder()) {
                        Ok(value) -> dekode.succeed(condition.equal(id, value))

                        Error(error) ->
                          dekode.fail(report.new(error.DecodeError(error)))
                      }

                    Ok(..) -> todo
                    Error(_) -> todo
                  }
                }
              }

            [#("unless", dynamic)] -> todo
            [#(_unknown, _)] -> todo
            _bad -> todo
          }
        })
    }
  })
}

fn task_decoder(
  fields: Dict(String, Dict(String, Dynamic)),
  filters: Dict(String, Dict(String, Dynamic)),
) -> State(Task, List(Report(Error)), dekode.Context(props.Context)) {
  use name <- props.required("name", dekode.string())
  use category <- props.required("category", dekode.list(decode.string))
  use id <- props.default("id", dekode.string(), make_id(category, name))
  use summary <- props.zero("summary", dekode.optional(decode.string))
  use description <- props.zero("description", dekode.optional(decode.string))
  use command <- props.zero("command", dekode.list(decode.string))
  use runners <- props.zero("runners", access_decoder())
  use approvers <- props.zero("approvers", access_decoder())
  let fields_decoder = field.decoder(_, fields, filters)
  use fields <- props.zero("fields", dekode.pairs(fields_decoder))

  dekode.succeed(Task(
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
