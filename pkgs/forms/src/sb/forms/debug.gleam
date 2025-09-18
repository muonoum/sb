import gleam/bool
import gleam/dict.{type Dict}
import gleam/float
import gleam/http
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
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

// id, kind: <kind> ==> value
// reference: @id
// literal list: [a, ..]
// literal object: {k=v, ..}
// fetch: body --> method url

pub fn format_task(task: Task) {
  string.join(format_fields(task.fields), "\n")
}

pub fn format_fields(fields: Dict(String, Field)) -> List(String) {
  use #(id, field) <- list.map(dict.to_list(fields))

  id
  <> format_kind(field.kind)
  <> " ==> "
  <> case kind.value(field.kind) {
    None -> "*"
    Some(Error(report)) -> format_report(report)
    Some(Ok(value)) -> format_value(value)
  }
}

fn format_kind(kind: Kind) -> String {
  case kind {
    kind.Data(source:) ->
      "=data" <> " " <> format_source_result(reset.unwrap(source))
    _else -> "todo-kind"
  }
}

fn format_source_result(result: Result(Source, Report(Error))) -> String {
  case result {
    Error(report) -> format_report(report)
    Ok(source) -> format_source(source)
  }
}

fn format_source(source: Source) -> String {
  case source {
    source.Literal(value) -> format_value(value)
    source.Fetch(method:, uri:, headers: _, body:) ->
      format_fetch(method, uri, body)
    source.Loading(..) -> format_loading()
    source.Reference(id) -> format_reference(id)
    source.Template(text) -> format_text(text)
    source.Command(_) -> "todo-command"
  }
}

fn format_report(_report: Report(Error)) -> String {
  "todo-report"
}

fn format_loading() -> String {
  "todo-loading"
}

fn format_reference(id: String) -> String {
  "@" <> id
}

fn format_fetch(method: http.Method, uri: Text, body: Option(Source)) -> String {
  [
    case body {
      None -> Error(Nil)
      Some(source) -> Ok(format_source(source) <> " -->")
    },

    Ok(http.method_to_string(method)),
    Ok(format_text(uri)),
  ]
  |> list.filter_map(function.identity)
  |> string.join(" ")
}

fn format_value(value: Value) -> String {
  case value {
    value.Bool(True) -> "true"
    value.Bool(False) -> "false"
    value.Float(float) -> float.to_string(float)
    value.Int(int) -> int.to_string(int)
    value.Null -> "null"
    value.String(string) -> string
    value.Object(object) -> format_object(object)
    value.List(list) -> format_list(list)
  }
}

fn format_list(list: List(Value)) -> String {
  "[" <> list.map(list, format_value) |> string.join(" ") <> "]"
}

fn format_object(pairs: List(#(String, Value))) -> String {
  let pairs = {
    use #(key, value) <- list.map(pairs)
    key <> "=" <> format_value(value)
  }

  "{" <> string.join(pairs, " ") <> "}"
}

fn format_text(text: Text) -> String {
  let parts = list.map(text.parts, format_text_part)
  "\"" <> string.join(parts, "") <> "\""
}

fn format_text_part(part: text.Part) -> String {
  case part {
    text.Placeholder -> format_interpolation("_")
    text.Reference(id) -> format_interpolation(id)
    text.Static(string) -> string
  }
}

fn format_interpolation(string: String) -> String {
  "{{" <> string <> "}}"
}

fn inspect_transition(value: String) -> String {
  ansi.grey(value)
}

pub fn inspect_scope(scope: Scope) -> String {
  let values = {
    use #(id, value) <- list.map(scope.to_list(scope))

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

pub fn inspect_fields(fields: Dict(String, Field)) -> List(String) {
  use #(id, field) <- list.map(dict.to_list(fields))
  inspect_id(id) <> " " <> inspect_kind(field.kind)
}

pub fn inspect_id(id: String) -> String {
  ansi.green(id)
}

fn inspect_kind_name(name: String) -> String {
  ansi.underline(ansi.grey(name))
}

fn inspect_kind(kind: Kind) -> String {
  case kind {
    kind.Data(source:) ->
      inspect_kind_name("data")
      <> " "
      <> inspect_reset_source(source)
      <> inspect_transition(" ==> ")
      <> case kind.value(kind) {
        None -> inspect_empty()
        Some(Error(report)) -> inspect_report(report)
        Some(Ok(value)) -> inspect_value(value)
      }

    kind.Text(string, ..) | kind.Textarea(string, ..) ->
      inspect_kind_name("text") <> " " <> string

    kind.Radio(choice:, options:, ..) ->
      inspect_kind_name("radio")
      <> " "
      <> inspect_options(options)
      <> inspect_transition(" ==> ")
      <> single_selected(choice)

    kind.Select(choice:, options:, ..) ->
      inspect_kind_name("select")
      <> " "
      <> inspect_options(options)
      <> inspect_transition(" ==> ")
      <> single_selected(choice)

    kind.Checkbox(selected, options:, ..) ->
      inspect_kind_name("checkbox")
      <> " "
      <> inspect_options(options)
      <> inspect_transition(" ==> ")
      <> multiple_selected(selected)

    kind.MultiSelect(selected, options:, ..) ->
      inspect_kind_name("multi select")
      <> " "
      <> inspect_options(options)
      <> inspect_transition(" ==> ")
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
    source.Reference(id) -> inspect_id("@" <> id)
    source.Template(text) -> inspect_text(text)
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
    case body {
      None -> Error(Nil)

      Some(source) ->
        Ok([
          inspect_source(source),
          inspect_transition("-->"),
        ])
    },
    Ok([
      ansi.cyan(http.method_to_string(method)),
      inspect_text(uri),
    ]),
  ]
  |> list.filter_map(function.identity)
  |> list.flatten
  |> string.join(" ")
}

pub fn inspect_text(text: Text) -> String {
  let parts = {
    use part <- list.map(text.parts)

    case part {
      text.Placeholder -> inspect_interpolation("_")
      text.Reference(id) -> inspect_interpolation(id)
      text.Static(string) -> string
    }
  }

  "\"" <> string.join(parts, "") <> "\""
}

fn inspect_interpolation(string: String) -> String {
  ansi.grey("{{") <> ansi.white(string) <> ansi.grey("}}")
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
    Some(choice) -> inspect_choice(choice)
    None -> inspect_empty()
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
    None -> inspect_empty()
    Some(value) -> inspect_value(value)
  }
}

pub fn inspect_value(value: Value) -> String {
  case value {
    value.Null -> ansi.grey("∅")
    value.Bool(_bool) -> inspect_todo("bool")
    value.Float(float) -> ansi.magenta(float.to_string(float))
    value.Int(int) -> ansi.magenta(int.to_string(int))

    value.List(list) ->
      "[" <> list.map(list, inspect_value) |> string.join(" ") <> "]"

    value.Object(pairs) -> {
      let pairs = {
        use #(key, value) <- list.map(pairs)
        key <> "=" <> inspect_value(value)
      }

      "{" <> string.join(pairs, " ") <> "}"
    }

    value.String(string) -> ansi.cyan(string)
  }
}

fn inspect_todo(text: String) -> String {
  ansi.black(ansi.bg_red("TODO(" <> text <> ")"))
}
