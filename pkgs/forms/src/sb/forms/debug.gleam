import gleam/bool
import gleam/dict.{type Dict}
import gleam/float
import gleam/http
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam_community/ansi
import sb/extra/function.{identity}
import sb/extra/report.{type Report}
import sb/extra/reset.{type Reset}
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

// id: checkbox-mixed-options
//   kind: checkbox
//   options: [ichi=en ni san]
//   selected: [ichi=en ichi=en ni san]
//   value: [en en ni san]

const field_separator = ""

pub fn task(task: Task) {
  format_fields(task.fields)
  |> list.intersperse(theme_diminished(field_separator))
  |> lined
}

pub fn scope(scope: Scope) -> String {
  let values = {
    use #(id, value) <- list.map(scope.to_list(scope))

    key_value(id, case value {
      Error(report) -> format_report(report)
      Ok(value) -> format_value(value)
    })
  }

  use <- bool.guard(values == [], format_empty())
  spaced(values)
}

// FORMATTERS

fn format_fields(fields: Dict(String, Field)) -> List(String) {
  use #(id, field) <- list.map(dict.to_list(fields))

  let id =
    spaced([
      label(format_kind_name(field.kind)),
      theme_id(id),
    ])

  let kind = format_kind(field.kind)

  let value =
    spaced([
      label("value"),
      case kind.value(field.kind) {
        None -> format_empty()
        Some(Error(report)) -> format_report(report)
        Some(Ok(value)) -> format_value(value)
      },
    ])

  lined(
    [[id], kind, [value]]
    |> list.flatten,
  )
}

fn format_kind_name(kind: Kind) -> String {
  case kind {
    kind.Checkbox(..) -> "checkbox"
    kind.Data(..) -> "data"
    kind.MultiSelect(..) -> "multi-select"
    kind.Radio(..) -> "radio"
    kind.Select(..) -> "select"
    kind.Text(..) -> "text"
    kind.Textarea(..) -> "textarea"
  }
}

fn format_empty() -> String {
  theme_empty("*")
}

fn format_report(report: Report(Error)) -> String {
  theme_error(string.inspect(report.issue(report)))
}

fn format_text(text: Text) -> String {
  quoted(joined(list.map(text.parts, format_text_part)))
}

fn format_text_part(part: text.Part) -> String {
  case part {
    text.Placeholder -> interpolated("_")
    text.Reference(id) -> interpolated(id)
    text.Static(string) -> string
  }
}

// KINDS

fn format_kind(kind: Kind) -> List(String) {
  case kind {
    kind.Data(source:) -> format_data_kind(source)
    kind.Text(string:, ..) -> format_text_kind(string)
    kind.Textarea(string:, ..) -> format_textarea_kind(string)
    kind.Checkbox(selected:, options:, ..) ->
      format_multiple_choice(selected, options)
    kind.Radio(selected:, options:, ..) ->
      format_single_choice(selected, options)
    kind.MultiSelect(selected:, options:, ..) ->
      format_multiple_choice(selected, options)
    kind.Select(selected:, options:, ..) ->
      format_single_choice(selected, options)
  }
}

fn format_data_kind(
  source: Reset(Result(Source, Report(Error))),
) -> List(String) {
  [spaced([label("source"), format_reset_source(source)])]
}

fn format_text_kind(string: String) -> List(String) {
  [spaced([label("string"), string])]
}

fn format_textarea_kind(string: String) -> List(String) {
  [spaced([label("string"), string])]
}

fn format_multiple_choice(
  choices: List(Value),
  options: Options,
) -> List(String) {
  let options = spaced([label("options"), format_options(options)])
  let selected = spaced([label("selected"), format_multiple_selected(choices)])
  [options, selected]
}

fn format_single_choice(value: Option(Value), options: Options) -> List(String) {
  let options = spaced([label("options"), format_options(options)])
  let selected = spaced([label("selected"), format_single_selected(value)])
  [options, selected]
}

// SOURCE

fn format_reset_source(source: Reset(Result(Source, Report(Error)))) -> String {
  case reset.unwrap(source) {
    Error(report) -> format_report(report)
    Ok(source) -> format_source(source)
  }
}

// fn format_source_result(result: Result(Source, Report(Error))) -> String {
//   case result {
//     Error(report) -> format_report(report)
//     Ok(source) -> format_source(source)
//   }
// }

fn format_source(source: Source) -> String {
  case source {
    source.Literal(value) -> format_value(value)
    source.Fetch(method:, uri:, headers: _, body:) ->
      format_fetch_source(method, uri, body)
    source.Loading(..) -> format_loading_source()
    source.Reference(id) -> format_reference_source(id)
    source.Template(text) -> format_text(text)
    source.Command(_) -> "command!"
  }
}

// SOURCE KINDS

fn format_loading_source() -> String {
  "loading!"
}

fn format_reference_source(id: String) -> String {
  "@" <> id
}

fn format_fetch_source(
  method: http.Method,
  uri: Text,
  body: Option(Source),
) -> String {
  let body = {
    use source <- result.map(option.to_result(body, Nil))
    format_source(source) <> " -->"
  }

  spaced(
    [body, Ok(http.method_to_string(method)), Ok(format_text(uri))]
    |> list.filter_map(identity),
  )
}

// VALUES

fn format_value(value: Value) -> String {
  case value {
    value.Null -> "null"
    value.Bool(True) -> theme_bool("true")
    value.Bool(False) -> theme_bool("false")
    value.String(string) -> theme_string(string)
    value.Int(int) -> theme_int(int.to_string(int))
    value.Float(float) -> theme_float(float.to_string(float))
    value.List(list) -> format_list(list)
    value.Pair(key, value) -> key_value(format_value(key), format_value(value))
    value.Object(object) -> format_object(object)
  }
}

fn format_list(list: List(Value)) -> String {
  square_bracketed(spaced(list.map(list, format_value)))
}

fn format_object(pairs: List(#(Value, Value))) -> String {
  curly_bracketed(
    spaced({
      use #(key, value) <- list.map(pairs)
      key_value(format_value(key), format_value(value))
    }),
  )
}

// OPTIONS

fn format_options(options: Options) -> String {
  case options.sources(options) {
    [source] -> format_reset_source(source)
    sources -> piped(list.map(sources, format_reset_source))
  }
}

fn format_single_selected(selected: Option(Value)) -> String {
  case selected {
    Some(value) -> format_value(value)
    None -> format_empty()
  }
}

fn format_multiple_selected(selected: List(Value)) -> String {
  case selected {
    [] -> format_empty()
    list -> square_bracketed(spaced(list.map(list, format_value)))
  }
}

// fn format_choice(choice: Choice) -> String {
//   let key = choice.key(choice)
//   let value = choice.value(choice)
//   use <- bool.guard(key == value, format_value(value))
//   key_value(format_value(key), format_value(value))
// }

// AUXILLARY

fn theme_diminished(string: String) -> String {
  ansi.gray(string)
}

fn theme_id(string: String) -> String {
  ansi.italic(string)
}

fn theme_error(string: String) -> String {
  ansi.red(string)
}

fn theme_empty(string: String) -> String {
  ansi.yellow(string)
}

fn theme_bool(string: String) -> String {
  ansi.magenta(string)
}

fn theme_string(string: String) -> String {
  ansi.green(string)
}

fn theme_float(string: String) -> String {
  ansi.pink(string)
}

fn theme_int(string: String) -> String {
  ansi.cyan(string)
}

fn label(string: String) -> String {
  // let assert Ok(colour) = colour.from_rgb(0.5, 0.5, 0.5)
  // ansi.colour(ansi.underline(ansi.bold(string)), colour)
  ansi.underline(ansi.bold(string))
}

fn surrounded(string: String, before: String, after: String) -> String {
  theme_diminished(before) <> string <> theme_diminished(after)
}

fn square_bracketed(string: String) -> String {
  surrounded(string, "[", "]")
}

// fn parened(string: String) -> String {
//   surrounded(string, "(", ")")
// }

fn curly_bracketed(string: String) -> String {
  surrounded(string, "{", "}")
}

fn quoted(string: String) -> String {
  surrounded(string, "\"", "\"")
}

fn interpolated(string: String) -> String {
  surrounded(string, "{{", "}}")
}

fn key_value(key: String, value: String) -> String {
  key <> theme_diminished("=") <> value
}

fn spaced(list: List(String)) -> String {
  string.join(list, " ")
}

fn joined(list: List(String)) -> String {
  string.join(list, "")
}

fn piped(list: List(String)) -> String {
  string.join(list, "|")
}

fn lined(list: List(String)) -> String {
  string.join(list, "\n")
}
