import gleam/bool
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option}
import gleam/string
import gleam_community/ansi
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
import sb/forms/value.{type Value}

pub fn inspect_task(task: Task) {
  inspect_fields(task.fields)
  |> string.join("\n")
}

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

  use <- bool.guard(values == [], ansi.yellow("*"))
  string.join(values, " ")
}

pub fn inspect_fields(fields: dict.Dict(String, Field)) -> List(String) {
  use #(id, field) <- list.map(dict.to_list(fields))
  ansi.green(id) <> " " <> inspect_kind(field.kind)
}

fn inspect_kind(kind: Kind) -> String {
  case kind {
    kind.Data(source:) ->
      ansi.grey("data ")
      <> inspect_source(source)
      <> ansi.grey(" ==> ")
      <> case kind.value(kind) {
        option.None -> ansi.yellow("*")
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

fn inspect_report(report: Report(Error)) -> String {
  ansi.red(string.inspect(report.issue(report)))
}

fn inspect_choice(choice: Choice) -> String {
  inspect_value(choice.key(choice))
  <> "="
  <> inspect_value(choice.value(choice))
}

fn single_selected(selected: Option(Choice)) -> String {
  case selected {
    option.Some(choice) -> inspect_choice(choice)
    option.None -> ansi.yellow("*")
  }
}

fn multiple_selected(selected: List(Choice)) -> String {
  case selected {
    [] -> ansi.yellow("*")
    list ->
      "["
      <> list.map(list, inspect_choice)
      |> string.join(" ")
      <> "]"
  }
}

fn inspect_options(options: Options) -> String {
  case options.sources(options) {
    [source] -> inspect_source(source)

    sources -> {
      list.map(sources, inspect_source)
      |> string.join("|")
    }
  }
}

fn inspect_source(source: Reset(Result(Source, Report(Error)))) -> String {
  case reset.unwrap(source) {
    Error(report) -> inspect_report(report)
    Ok(source.Literal(value)) -> inspect_value(value)
    Ok(source.Loading(..)) -> ansi.yellow("Loading")
    Ok(source.Reference(id)) -> ansi.grey("-->") <> ansi.pink(id)
    Ok(source.Template(_text)) -> inspect_todo("template")
    Ok(source.Command(_text)) -> inspect_todo("command")
    Ok(source.Fetch(..)) -> inspect_todo("fetch")
  }
}

fn inspect_todo(text: String) -> String {
  ansi.black(ansi.bg_red("TODO[" <> text <> "]"))
}

pub fn inspect_option_value(
  value: Option(Result(Value, Report(Error))),
) -> String {
  case value {
    option.None -> ansi.yellow("*")
    option.Some(Error(report)) -> inspect_report(report)
    option.Some(Ok(value)) -> inspect_value(value)
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
