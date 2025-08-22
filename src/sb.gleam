import gleam/dict
import gleam/io
import gleam/option.{None}
import gleam_community/ansi
import sb/field.{Field}
import sb/inspect
import sb/kind
import sb/options
import sb/reset
import sb/source
import sb/task.{Task}
import sb/value

pub fn main() -> Nil {
  let strings =
    value.List([value.String("a"), value.String("b"), value.String("c")])
  let string = value.String("str")
  let object = source.Literal(value.Object([#("en", strings), #("to", string)]))

  let radio1 = kind.Radio(None, options.SingleSource(reset.new(Ok(object), [])))

  let radio2 =
    kind.Radio(
      None,
      options.SingleSource(reset.new(Ok(source.Reference("1")), ["1"])),
    )

  let checkbox1 =
    kind.Checkbox([], options.SingleSource(reset.new(Ok(object), [])))

  let checkbox2 =
    kind.Checkbox(
      [],
      options.SingleSource(reset.new(Ok(source.Reference("1")), ["1"])),
    )

  let task =
    Task(
      dict.from_list([
        #("1", Field(radio1)),
        #("2", Field(radio2)),
        // #("1", Field(checkbox1)),
      // #("2", Field(checkbox2)),
      ]),
    )

  let scope = dict.new()
  let #(task, scope) = task.evaluate(task, scope)
  inspect.task(task)

  io.println(ansi.grey("# 1 select \"en\" "))
  let assert Ok(task) = task.update(task, "1", value.String("en"))
  // let assert Ok(task) = task.update(task, "1", value.List([value.String("en")]))
  let #(task, scope) = task.evaluate(task, scope)
  inspect.task(task)

  io.println(ansi.grey("# 2 select \"a\" "))
  let assert Ok(task) = task.update(task, "2", value.String("a"))
  // let assert Ok(task) = task.update(task, "2", value.List([strings]))
  let #(task, scope) = task.evaluate(task, scope)
  inspect.task(task)

  io.println(ansi.grey("# 1 select \"to\" "))
  let assert Ok(task) = task.update(task, "1", value.String("to"))
  // let assert Ok(task) = task.update(task, "1", value.List([value.String("to")]))
  let #(task, scope) = task.evaluate(task, scope)
  inspect.task(task)

  Nil
}
