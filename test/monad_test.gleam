import gleam/int
import gleam/io
import sb/extra/reader
import sb/extra/state

pub fn main() {
  let changer = fn(value) { value + 1 }

  let printer = fn(tag, value) {
    io.println(tag <> ": " <> int.to_string(value))
  }

  let reader_printer = fn(tag) {
    use value <- reader.bind(reader.ask)
    reader.return(printer("reader[" <> tag <> "]", value))
  }

  let state_printer = fn(tag) {
    use value <- state.bind(state.get())
    state.return(printer("state[" <> tag <> "]", value))
  }

  reader.run(context: 1, reader: {
    use <- reader.do(reader_printer("before"))
    use <- reader.do(reader.local(reader_printer("local"), changer))
    use <- reader.do(reader_printer("after"))
    reader.return(Nil)
  })

  state.run(context: 1, state: {
    use <- state.do(state_printer("before"))

    use <- state.do({
      use <- state.do(state.update(changer))
      state_printer("update")
    })

    use <- state.do(state_printer("after"))
    state.return(Nil)
  })
}
