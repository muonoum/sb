import gleam/dict
import gleam/io
import gleam/list
import gleam/option.{type Option}
import gleam/string
import gleam_community/ansi
import sb/error.{type Error}
import sb/kind.{type Kind}
import sb/options.{type Options}
import sb/reset.{type Reset}
import sb/source.{type Source}
import sb/task.{type Task}
import sb/value.{type Value}

pub fn task(task: Task) -> Task {
  dict.map_values(task.fields, fn(id, field) {
    io.println(ansi.green(id) <> " " <> inspect_kind(field.kind))
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

fn single_selected(selected: Option(Value)) -> String {
  option.map(selected, inspect_value)
  |> option.unwrap(ansi.grey("*"))
}

fn multiple_selected(selected: List(Value)) -> String {
  case selected {
    [] -> ansi.grey("*")
    list -> "[" <> list.map(list, inspect_value) |> string.join(",") <> "]"
  }
}

fn inspect_options(options: Options) -> String {
  case options {
    options.SingleSource(source) -> inspect_source(source)

    options.SourceGroups(groups) -> {
      let groups = {
        use options.Group(label, source) <- list.map(groups)
        "Group(" <> label <> " " <> inspect_source(source) <> ")"
      }

      "Groups(" <> string.join(groups, ",") <> ")"
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

fn inspect_value(value: Value) -> String {
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
