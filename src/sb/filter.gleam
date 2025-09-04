import extra
import extra/state
import gleam/dict
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/result
import sb/custom
import sb/decoder
import sb/error.{type Error}
import sb/props.{type Props}
import sb/report.{type Report}
import sb/value.{type Value}
import sb/zero

const succeed_keys = ["kind"]

const fail_keys = ["kind", "error-message"]

const expect_keys = ["kind", "value", "error-message"]

const parse_integer_keys = ["kind"]

const parse_float_keys = ["kind"]

pub type Filter {
  Succeed
  Fail(error_message: String)
  Expect(value: Value, error_message: Option(String))
  ParseInteger
  ParseFloat
}

pub fn evaluate(value: Value, filter: Filter) -> Result(Value, Report(Error)) {
  case filter {
    Succeed -> Ok(value)

    Fail(error_message:) -> report.error(error.Message(error_message))

    Expect(value: expected, error_message:) ->
      case expected == value, error_message {
        True, _error_message -> Ok(value)
        False, Some(error_message) -> report.error(error.Message(error_message))

        False, None ->
          report.error(error.BadValue(value))
          |> report.error_context(error.Expected(expected))
      }

    ParseInteger ->
      case value {
        value.String(string) ->
          int.parse(string)
          |> report.replace_error(error.BadValue(value))
          |> result.map(value.Int)

        value.Int(_) -> Ok(value)
        value -> report.error(error.BadValue(value))
      }

    ParseFloat ->
      case value {
        value.String(string) ->
          float.parse(string)
          |> report.replace_error(error.BadValue(value))
          |> result.map(value.Float)

        value.Float(_) -> Ok(value)
        value.Int(int) -> Ok(value.Float(int.to_float(int)))
        value -> report.error(error.BadValue(value))
      }
  }
}

pub fn decoder(filters: custom.Filters) -> Props(Filter) {
  use name <- props.required("kind", {
    zero.string(decoder.from(decode.string))
  })

  let context = report.context(_, error.BadKind(name))
  use <- extra.return(state.map_error(_, context))

  use <- result.lazy_unwrap({
    use custom <- result.map(dict.get(filters.custom, name))
    use <- state.do(props.merge(custom))
    decoder(filters)
  })

  case name {
    "succeed" -> succeed_decoder()
    "fail" -> fail_decoder()
    "expect" -> expect_decoder()
    "parse-integer" -> parse_integer_decoder()
    "parse-float" -> parse_float_decoder()
    unknown -> state.fail(report.new(error.UnknownKind(unknown)))
  }
}

fn succeed_decoder() -> Props(Filter) {
  use <- state.do(props.check_keys(succeed_keys))
  state.succeed(Succeed)
}

fn fail_decoder() -> Props(Filter) {
  use <- state.do(props.check_keys(fail_keys))

  use error_message <- props.required("error-message", {
    zero.string(decoder.from(decode.string))
  })

  state.succeed(Fail(error_message:))
}

fn expect_decoder() -> Props(Filter) {
  use <- state.do(props.check_keys(expect_keys))

  use value <- props.required("value", {
    zero.new(decoder.from(value.decoder()), value.zero)
  })

  use error_message <- props.zero("error-message", {
    zero.option(decoder.from(decode.map(decode.string, Some)))
  })

  state.succeed(Expect(value:, error_message:))
}

fn parse_integer_decoder() -> Props(Filter) {
  use <- state.do(props.check_keys(parse_integer_keys))
  state.succeed(ParseInteger)
}

fn parse_float_decoder() -> Props(Filter) {
  use <- state.do(props.check_keys(parse_float_keys))
  state.succeed(ParseFloat)
}
