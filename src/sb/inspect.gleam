import gleam/dict
import gleam/io
import gleam/list
import gleam/option.{type Option}
import gleam/string
import gleam_community/ansi
import sb/choice.{type Choice}
import sb/error.{type Error}
import sb/field
import sb/kind.{type Kind}
import sb/options.{type Options}
import sb/reset.{type Reset}
import sb/source.{type Source}
import sb/task.{type Task}
import sb/value.{type Value}

pub fn task(task: Task) -> Task {
  dict.map_values(task.fields, fn(id, field) {
    io.println(ansi.green(id) <> " " <> inspect_kind(field.kind(field)))
  })

  task
}

fn inspect_kind(kind: Kind) -> String {
  case kind {
    kind.Data(source:) -> inspect_source(source)
    kind.Text(string) | kind.Textarea(string) -> string

    kind.Radio(selected, options:) | kind.Select(selected, options:) ->
      inspect_options(options) <> " => " <> single_selected(selected)

    kind.Checkbox(selected, options:) | kind.MultiSelect(selected, options:) ->
      inspect_options(options) <> " => " <> multiple_selected(selected)
  }
}

fn inspect_choice(choice: Choice) -> String {
  inspect_value(choice.key(choice))
  <> "="
  <> inspect_value(choice.value(choice))
}

fn single_selected(selected: Option(Choice)) -> String {
  case selected {
    option.Some(choice) -> inspect_choice(choice)
    option.None -> ansi.grey("*")
  }
}

fn multiple_selected(selected: List(Choice)) -> String {
  case selected {
    [] -> ansi.grey("*")
    list ->
      "["
      <> list.map(list, inspect_choice)
      |> string.join(",")
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

fn inspect_source(source: Reset(Result(Source, Error))) -> String {
  case reset.unwrap(source) {
    Error(error) -> ansi.red(string.inspect(error))
    Ok(source.Literal(value)) -> inspect_value(value)
    Ok(source.Loading(..)) -> ansi.yellow("Loading")
    Ok(source.Reference(id)) -> "->" <> ansi.pink(id)
  }
}

pub fn inspect_value(value: Value) -> String {
  case value {
    value.List(list) ->
      "#[" <> list.map(list, inspect_value) |> string.join(",") <> "]"

    value.Object(pairs) -> {
      let pairs = {
        use #(key, value) <- list.map(pairs)
        key <> "=" <> inspect_value(value)
      }

      "#{" <> string.join(pairs, ",") <> "}"
    }

    value.String(string) -> ansi.cyan(string)
  }
}
