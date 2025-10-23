import gleam/int
import gleam/string
import sb/extra/parser.{type Parser}

pub fn parser() -> Parser(String, Int) {
  let number = {
    use digits <- parser.keep(parser.some(
      parser.expect(string.contains("01234567890", _))
      |> parser.label("base 10 digit"),
    ))

    let number = string.join(digits, "")

    case int.parse(number) {
      Error(Nil) -> parser.fail(parser.unexpected(number))
      Ok(int) -> parser.succeed(int)
    }
  }

  let seconds = {
    use <- parser.drop(parser.string("s"))
    use <- parser.drop(parser.end())
    use number <- parser.succeed
    number * 1000
  }

  let minutes_or_milliseconds = {
    use <- parser.drop(parser.string("m"))

    let minutes = {
      use <- parser.drop(parser.end())
      use number <- parser.succeed
      number * 1000 * 60
    }

    let milliseconds = {
      use <- parser.drop(parser.string("s"))
      use <- parser.drop(parser.end())
      use number <- parser.succeed
      number
    }

    parser.one_of([minutes, milliseconds])
  }

  use number <- parser.keep(number)

  use unit <- parser.keep(
    parser.one_of([minutes_or_milliseconds, seconds])
    |> parser.label("unit"),
  )

  parser.succeed(unit(number))
}
