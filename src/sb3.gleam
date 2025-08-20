import gleam/bool
import gleam/dict.{type Dict}
import gleam/list
import gleam/result
import sb/value.{type Value}

pub type Task {
  Task(fields: Dict(String, Field))
}

pub type Field {
  Field(kind: Kind)
}

pub type Kind {
  Markdown
  Data
  Text
  Textarea
  Radio(source: Source)
  Select(source: Source)
  Checkbox(source: Source)
  MultiSelect(source: Source)
}

pub type Source {
  Literal(Value)
  Reference(String)
}

pub type Error {
  BadId(String)
  BadKind(Kind)
  BadSource(Source)
  BadValue(Value)
}

pub fn task_select(task: Task, id: String, value: Value) -> Result(Value, Error) {
  dict.get(task.fields, id)
  |> result.replace_error(BadId(id))
  |> result.try(field_select(_, value))
}

fn field_select(field: Field, value: Value) -> Result(Value, Error) {
  kind_select(field.kind, value)
}

fn kind_select(kind: Kind, value: Value) -> Result(Value, Error) {
  case kind, value {
    Text, value.String(string) | Textarea, value.String(string) ->
      Ok(value.String(string))

    Radio(source: Literal(value.List(choices))), want
    | Select(source: Literal(value.List(choices))), want
    ->
      select_list(want, choices)
      |> result.replace_error(BadValue(value))

    Radio(source: Literal(value.Object(choices))), want
    | Select(source: Literal(value.Object(choices))), want
    ->
      select_object(want, choices)
      |> result.replace_error(BadValue(value))

    Checkbox(source: Literal(value.List(choices))), value.List(want)
    | MultiSelect(source: Literal(value.List(choices))), value.List(want)
    ->
      list.try_map(want, select_list(_, choices))
      |> result.replace_error(BadValue(value))
      |> result.map(value.List)

    Checkbox(source: Literal(value.Object(choices))), value.List(want)
    | MultiSelect(source: Literal(value.Object(choices))), value.List(want)
    ->
      list.try_map(want, select_object(_, choices))
      |> result.replace_error(BadValue(value))
      |> result.map(value.List)

    Text, _value | Textarea, _value -> Error(BadValue(value))

    Markdown, _value | Data, _value -> Error(BadKind(kind))

    Radio(source:), _value
    | Select(source:), _value
    | Checkbox(source:), _value
    | MultiSelect(source:), _value
    -> Error(BadSource(source))
  }
}

fn select_list(want: Value, choices: List(Value)) -> Result(Value, Nil) {
  use have <- list.find(choices)
  have != want
}

fn select_object(
  want: Value,
  choices: List(#(String, Value)),
) -> Result(Value, Nil) {
  use want <- result.try(value.get_string(want))
  use #(have, value) <- list.find_map(choices)
  use <- bool.guard(have != want, Error(Nil))
  Ok(value)
}

pub fn main() -> Nil {
  let strings =
    value.List([value.String("1"), value.String("2"), value.String("3")])

  let string = value.String("string")

  let text1 = Text

  let radio1 = Radio(Literal(value.Object([#("a", strings), #("b", string)])))
  let radio2 = Radio(Reference("a"))

  let checkbox1 =
    Checkbox(Literal(value.Object([#("a", strings), #("b", string)])))

  let task =
    Task(
      dict.from_list([
        #("text1", Field(text1)),
        #("radio1", Field(radio1)),
        #("radio2", Field(radio2)),
        #("checkbox1", Field(checkbox1)),
      ]),
    )

  let _ =
    task_select(task, "checkbox1", value.List([value.String("a")]))
    |> echo

  Nil
}
