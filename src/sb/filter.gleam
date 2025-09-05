import extra/state
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/result
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

pub fn decoder(
  name: String,
  check_keys: fn(List(String)) -> Props(Nil),
) -> Props(Filter) {
  case name {
    "succeed" ->
      state.do(check_keys(succeed_keys), succeed_decoder)
      |> props.error_context(error.BadKind(name))

    "fail" ->
      state.do(check_keys(fail_keys), fail_decoder)
      |> props.error_context(error.BadKind(name))

    "expect" ->
      state.do(check_keys(expect_keys), expect_decoder)
      |> props.error_context(error.BadKind(name))

    "parse-integer" ->
      state.do(check_keys(parse_integer_keys), parse_integer_decoder)
      |> props.error_context(error.BadKind(name))

    "parse-float" ->
      state.do(check_keys(parse_float_keys), parse_float_decoder)
      |> props.error_context(error.BadKind(name))

    unknown -> state.fail(report.new(error.UnknownKind(unknown)))
  }
}

fn succeed_decoder() -> Props(Filter) {
  state.succeed(Succeed)
}

fn fail_decoder() -> Props(Filter) {
  use error_message <- props.get("error-message", decoder.from(decode.string))
  state.succeed(Fail(error_message:))
}

fn expect_decoder() -> Props(Filter) {
  use value <- props.get("value", decoder.from(value.decoder()))

  use error_message <- props.try("error-message", {
    zero.option(decoder.from(decode.string))
  })

  state.succeed(Expect(value:, error_message:))
}

fn parse_integer_decoder() -> Props(Filter) {
  state.succeed(ParseInteger)
}

fn parse_float_decoder() -> Props(Filter) {
  state.succeed(ParseFloat)
}
