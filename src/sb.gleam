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
      options.SingleSource(reset.new(Ok(source.Reference("r1")), ["r1"])),
    )

  let checkbox1 =
    kind.Checkbox([], options.SingleSource(reset.new(Ok(object), [])))

  let checkbox2 =
    kind.Checkbox(
      [],
      options.SingleSource(reset.new(Ok(source.Reference("c1")), ["c1"])),
    )

  // fields:
  //   id: c1
  //   kind: checkbox
  //   source.literal:
  //     - en: [a, b, c]
  //     - to: str
  // 
  //   id: c2
  //   kind: checkbox
  //   source.reference: c1
  //
  //   c1 select "en", "to"
  //   c1 => [[a, b, c], str]
  //   c2 => [[a, b, c], str]

  let task =
    Task(
      dict.from_list([
        #("r1", Field(radio1)),
        #("r2", Field(radio2)),
        // #("c1", Field(checkbox1)),
      // #("c2", Field(checkbox2)),
      ]),
    )

  let scope = dict.new()
  let #(task, scope) = task.evaluate(task, scope)
  inspect.task(task)

  // io.println(ansi.grey("# c1 select [\"en\"] "))
  // let assert Ok(task) =
  //   task.update(
  //     task,
  //     "c1",
  //     value.List([value.String("en"), value.String("to")]),
  //   )

  io.println(ansi.grey("# r1 select \"en\" "))
  let assert Ok(task) = task.update(task, "r1", value.String("en"))
  let #(task, scope) = task.evaluate(task, scope)
  inspect.task(task)

  io.println(ansi.grey("# r2 select \"a\" "))
  let assert Ok(task) = task.update(task, "r2", value.String("a"))
  let #(task, scope) = task.evaluate(task, scope)
  inspect.task(task)

  io.println(ansi.grey("# r1 select \"to\" "))
  let assert Ok(task) = task.update(task, "r1", value.String("to"))
  let #(task, scope) = task.evaluate(task, scope)
  inspect.task(task)

  // io.println(ansi.grey("# c2 select [\"b\"] "))
  // let assert Ok(task) = task.update(task, "c2", value.List([value.String("b")]))
  // let #(task, scope) = task.evaluate(task, scope)
  // inspect.task(task)

  // io.println(ansi.grey("# c1 select []"))
  // let assert Ok(task) = task.update(task, "c1", value.List([]))
  // let #(task, _scope) = task.evaluate(task, scope)
  // inspect.task(task)

  Nil
}
