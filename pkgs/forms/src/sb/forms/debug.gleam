import gleam/bool
import gleam/dict
import gleam/http
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/string
import gleam_community/ansi
import sb/extra/function
import sb/extra/report.{type Report}
import sb/extra/reset.{type Reset}
import sb/forms/choice.{type Choice}
import sb/forms/error.{type Error}
import sb/forms/field.{type Field}
import sb/forms/kind.{type Kind}
import sb/forms/options.{type Options}
import sb/forms/scope.{type Scope}
import sb/forms/source.{type Source}
import sb/forms/task.{type Task}
import sb/forms/text.{type Text}
import sb/forms/value.{type Value}

pub fn inspect_scope(scope: Scope) -> String {
  let values = {
    use #(id, value) <- list.map(dict.to_list(scope))

    id
    <> ansi.grey("=")
    <> case value {
      Error(report) -> inspect_report(report)
      Ok(value) -> inspect_value(value)
    }
  }

  use <- bool.guard(values == [], inspect_empty())
  string.join(values, " ")
}

pub fn inspect_empty() -> String {
  ansi.yellow("*")
}

pub fn inspect_task(task: Task) {
  string.join(inspect_fields(task.fields), "\n")
}

pub fn inspect_fields(fields: dict.Dict(String, Field)) -> List(String) {
  use #(id, field) <- list.map(dict.to_list(fields))
  inspect_id(id) <> " " <> inspect_kind(field.kind)
}

pub fn inspect_id(id: String) -> String {
  ansi.green(id)
}

fn inspect_kind(kind: Kind) -> String {
  case kind {
    kind.Data(source:) ->
      ansi.grey("data ")
      <> inspect_reset_source(source)
      <> ansi.grey(" ==> ")
      <> case kind.value(kind) {
        option.None -> inspect_empty()
        option.Some(Error(report)) -> inspect_report(report)
        option.Some(Ok(value)) -> inspect_value(value)
      }

    kind.Text(string, ..) | kind.Textarea(string, ..) ->
      ansi.grey("str ") <> string

    kind.Radio(choice:, options:, ..) ->
      ansi.grey("radio ")
      <> inspect_options(options)
      <> ansi.grey(" ==> ")
      <> single_selected(choice)

    kind.Select(choice:, options:, ..) ->
      ansi.grey("select ")
      <> inspect_options(options)
      <> ansi.grey(" ==> ")
      <> single_selected(choice)

    kind.Checkbox(selected, options:, ..) ->
      ansi.grey("checkbox ")
      <> inspect_options(options)
      <> ansi.grey(" ==> ")
      <> multiple_selected(selected)

    kind.MultiSelect(selected, options:, ..) ->
      ansi.grey("multiselect ")
      <> inspect_options(options)
      <> ansi.grey(" ==> ")
      <> multiple_selected(selected)
  }
}

fn inspect_reset_source(source: Reset(Result(Source, Report(Error)))) -> String {
  case reset.unwrap(source) {
    Error(report) -> inspect_report(report)
    Ok(source) -> inspect_source(source)
  }
}

fn inspect_source(source: Source) -> String {
  case source {
    source.Literal(value) -> inspect_value(value)
    source.Loading(..) -> ansi.yellow("Loading")
    source.Reference(id) -> ansi.grey("-->") <> ansi.pink(id)
    source.Template(_text) -> inspect_todo("template")
    source.Command(_text) -> inspect_todo("command")
    source.Fetch(method:, uri:, headers:, body:) ->
      inspect_fetch(method, uri, headers, body)
  }
}

fn inspect_fetch(
  method: http.Method,
  uri: Text,
  _headers: List(#(String, String)),
  body: Option(Source),
) -> String {
  [
    Ok([
      ansi.cyan(http.method_to_string(method)),
      inspect_text(uri),
    ]),
    case body {
      option.None -> Error(Nil)
      option.Some(source) -> Ok(["<--", inspect_source(source)])
    },
  ]
  |> list.filter_map(function.identity)
  |> list.flatten
  |> string.join(" ")
}

pub fn inspect_text(text: Text) -> String {
  let parts = {
    use part <- list.map(text.parts)

    case part {
      text.Placeholder -> "{{_}}"
      text.Reference(id) -> "{{" <> id <> "}}"
      text.Static(string) -> string
    }
  }

  string.join(parts, "")
}

fn inspect_options(options: Options) -> String {
  case options.sources(options) {
    [source] -> inspect_reset_source(source)

    sources -> {
      list.map(sources, inspect_reset_source)
      |> string.join("|")
    }
  }
}

fn single_selected(selected: Option(Choice)) -> String {
  case selected {
    option.Some(choice) -> inspect_choice(choice)
    option.None -> inspect_empty()
  }
}

fn multiple_selected(selected: List(Choice)) -> String {
  case selected {
    [] -> inspect_empty()
    list ->
      "["
      <> list.map(list, inspect_choice)
      |> string.join(" ")
      <> "]"
  }
}

fn inspect_choice(choice: Choice) -> String {
  inspect_value(choice.key(choice))
  <> "="
  <> inspect_value(choice.value(choice))
}

fn inspect_report(report: Report(Error)) -> String {
  ansi.red(string.inspect(report.issue(report)))
}

pub fn inspect_option_value(value: Option(Value)) -> String {
  case value {
    option.None -> inspect_empty()
    option.Some(value) -> inspect_value(value)
  }
}

pub fn inspect_value(value: Value) -> String {
  case value {
    value.Null -> inspect_todo("null")
    value.Bool(_bool) -> inspect_todo("bool")
    value.Float(_float) -> inspect_todo("float")
    value.Int(int) -> ansi.magenta(int.to_string(int))

    value.List(list) ->
      "#[" <> list.map(list, inspect_value) |> string.join(" ") <> "]"

    value.Object(pairs) -> {
      let pairs = {
        use #(key, value) <- list.map(pairs)
        key <> "=" <> inspect_value(value)
      }

      "#{" <> string.join(pairs, " ") <> "}"
    }

    value.String(string) -> ansi.cyan(string)
  }
}

fn inspect_todo(text: String) -> String {
  ansi.black(ansi.bg_red("TODO(" <> text <> ")"))
}
