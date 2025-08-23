import gleam/bool
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/set.{type Set}
import gleam/string
import gleam/yielder.{type Yielder}

// https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/parsec-paper-letter.pdf

pub opaque type Parser(i, v) {
  Parser(fn(State(i)) -> Consumed(i, v))
}

type Position =
  Int

type State(i) {
  State(input: Yielder(i), position: Position)
}

type Consumed(i, v) {
  Consumed(fn() -> Reply(i, v))
  Empty(fn() -> Reply(i, v))
}

pub type Unexpected(i) {
  UnexpectedEnd
  UnexpectedToken(i)
}

pub type Message(i) {
  Message(position: Position, error: Option(Unexpected(i)), labels: Set(String))
}

type Reply(i, v) {
  Success(value: v, state: State(i), message: Message(i))
  Failure(message: Message(i))
}

fn merge_reply(reply: Reply(i, v), message1: Message(i)) -> Reply(i, v) {
  case reply {
    Failure(message2) -> merge_failure(message1, message2)

    Success(value, state, message2) -> {
      merge_success(value, state, message1, message2)
    }
  }
}

fn merge_failure(message1: Message(i), message2: Message(i)) -> Reply(i, v) {
  Failure(merge_messages(message1, message2))
}

fn merge_success(
  value: v,
  state: State(i),
  message1: Message(i),
  message2: Message(i),
) -> Reply(i, v) {
  Success(value:, state:, message: merge_messages(message1, message2))
}

fn merge_messages(message1: Message(i), message2: Message(i)) -> Message(i) {
  let Message(position1, error1, labels1) = message1
  let Message(position2, error2, labels2) = message2

  case error1, error2 {
    Some(_), None -> message1
    None, Some(_) -> message2

    _other, _wise -> {
      use <- bool.guard(position1 > position2, message1)
      use <- bool.guard(position1 < position2, message2)
      Message(..message1, labels: set.union(labels1, labels2))
    }
  }
}

pub fn format_message(message: Message(i)) -> String {
  let Message(position:, error:, labels:) = message

  let line1 = "parse error at position " <> int.to_string(position)

  let line2 = case error {
    None -> "unknown error"
    Some(UnexpectedEnd) -> "unexpected end of input"
    Some(UnexpectedToken(token)) -> "unexpected " <> string.inspect(token)
  }

  case set.to_list(labels) {
    [] -> string.join([line1, line2], "\n")

    expected ->
      string.join(
        [line1, line2, "expected: " <> string.join(expected, ", ")],
        "\n",
      )
  }
}

fn run(parser: Parser(i, v), state: State(i)) -> Consumed(i, v) {
  let Parser(parser) = parser
  parser(state)
}

pub fn parse(input: Yielder(i), parser: Parser(i, v)) -> Result(v, Message(i)) {
  let state = State(input, 1)

  case run(parser, state) {
    Empty(reply) ->
      case reply() {
        Success(value, _state, _message) -> Ok(value)
        Failure(message) -> Error(message)
      }

    Consumed(reply) ->
      case reply() {
        Success(value, _state, _message) -> Ok(value)
        Failure(message) -> Error(message)
      }
  }
}

pub fn parse_string(
  string: String,
  parser: Parser(_, value),
) -> Result(value, Message(String)) {
  let input = {
    use state <- yielder.unfold(string)

    case string.pop_grapheme(state) {
      Error(Nil) -> yielder.Done
      Ok(#(grapheme, state)) -> yielder.Next(grapheme, state)
    }
  }

  parse(input, parser)
}

pub fn succeed(value: v) -> Parser(i, v) {
  use State(_input, position) as state <- Parser
  let message = Message(position:, error: None, labels: set.new())
  Empty(fn() { Success(value:, state:, message:) })
}

pub fn fail(error: Option(Unexpected(i))) -> Parser(i, v) {
  use State(_input, position) <- Parser
  let message = Message(position:, error:, labels: set.new())
  Empty(fn() { Failure(message:) })
}

pub fn expect(check: fn(i) -> Bool) -> Parser(i, i) {
  use State(input, position) <- Parser

  case yielder.step(input) {
    yielder.Done ->
      Empty(fn() {
        Failure(Message(
          position:,
          error: Some(UnexpectedEnd),
          labels: set.new(),
        ))
      })

    yielder.Next(value, rest) -> {
      case check(value) {
        True -> {
          let position = position + 1

          Consumed(fn() {
            Success(
              value:,
              state: State(rest, position),
              message: Message(position:, error: None, labels: set.new()),
            )
          })
        }

        False ->
          Empty(fn() {
            Failure(Message(
              position:,
              error: Some(UnexpectedToken(value)),
              labels: set.new(),
            ))
          })
      }
    }
  }
}

pub fn keep(parser: Parser(i, a), then: fn(a) -> Parser(i, b)) -> Parser(i, b) {
  use state <- Parser

  case run(parser, state) {
    Consumed(reply1) ->
      Consumed(fn() {
        case reply1() {
          Failure(message) -> Failure(message)

          Success(value, state, message1) ->
            case run(then(value), state) {
              Consumed(reply) -> reply()
              Empty(reply2) -> merge_reply(reply2(), message1)
            }
        }
      })

    Empty(reply1) ->
      case reply1() {
        Failure(message) -> Empty(fn() { Failure(message) })

        Success(value, state, message1) ->
          case run(then(value), state) {
            Empty(reply2) -> {
              Empty(fn() { merge_reply(reply2(), message1) })
            }

            Consumed(reply2) -> {
              Consumed(fn() { merge_reply(reply2(), message1) })
            }
          }
      }
  }
}

pub fn choice(a: Parser(i, v), b: Parser(i, v)) -> Parser(i, v) {
  use state <- Parser

  case run(a, state) {
    Consumed(reply) -> Consumed(reply)

    Empty(reply1) ->
      case run(b, state) {
        Consumed(reply2) -> Consumed(reply2)

        Empty(reply2) ->
          Empty(fn() {
            case reply1(), reply2() {
              Failure(message1), Failure(message2) ->
                merge_failure(message1, message2)

              Failure(message1), Success(value, state, message2) ->
                merge_success(value, state, message1, message2)

              Success(value, state, message1), Failure(message2) ->
                merge_success(value, state, message1, message2)

              Success(value, state, message1), Success(_value, _state, message2)
              -> merge_success(value, state, message1, message2)
            }
          })
      }
  }
}

pub fn label(parser: Parser(i, v), label: String) -> Parser(i, v) {
  use state <- Parser

  case run(parser, state) {
    Consumed(reply) -> Consumed(reply)

    Empty(reply) ->
      case reply() {
        Failure(message) -> Empty(fn() { Failure(put_label(message, label)) })

        Success(value:, state:, message:) ->
          Empty(fn() {
            Success(value:, state:, message: put_label(message, label))
          })
      }
  }
}

fn put_label(message: Message(i), label: String) -> Message(i) {
  let Message(position, error, _labels) = message
  Message(position:, error:, labels: set.from_list([label]))
}

pub fn try(parser: Parser(i, v)) -> Parser(i, v) {
  use state <- Parser

  case run(parser, state) {
    Empty(reply) -> Empty(reply)

    Consumed(reply) ->
      case reply() {
        Failure(message) -> Empty(fn() { Failure(message) })
        _success -> Consumed(reply)
      }
  }
}

pub fn lazy(parser: fn() -> Parser(i, v)) -> Parser(i, v) {
  use state <- Parser
  run(parser(), state)
}

pub fn end() -> Parser(_, Nil) {
  not_followed_by(any())
}

pub fn sequence(parsers: List(Parser(_, v))) -> Parser(_, List(v)) {
  use result, parser <- list.fold_right(parsers, succeed([]))
  use value <- keep(parser)
  use result <- map(_, result)
  [value, ..result]
}

pub fn maybe_or(parser: Parser(_, v), default: v) -> Parser(_, v) {
  choice(parser, succeed(default))
}

pub fn unwrap(parser: Parser(_, Option(v)), default default: v) -> Parser(_, v) {
  map(option.unwrap(_, or: default), parser)
}

pub fn maybe(parser: Parser(_, v)) -> Parser(_, Option(v)) {
  map(Some, parser)
  |> maybe_or(None)
}

pub fn between(
  parser: Parser(_, c),
  open: Parser(_, a),
  close: Parser(_, b),
) -> Parser(_, c) {
  use <- drop(open)
  use value <- keep(parser)
  use <- drop(close)
  succeed(value)
}

pub fn separated_by(
  parser: Parser(_, a),
  separator separator: Parser(_, b),
) -> Parser(_, List(a)) {
  separated_by1(parser, separator)
  |> choice(succeed([]))
}

pub fn separated_by1(
  parser: Parser(_, a),
  separator: Parser(_, b),
) -> Parser(_, List(a)) {
  use v <- keep(parser)

  use vs <- keep(
    many({
      use <- drop(separator)
      use v <- keep(parser)
      succeed(v)
    }),
  )

  succeed([v, ..vs])
}

pub fn collect(parser: Parser(_, b), until end: Parser(_, a)) -> Parser(_, b) {
  use <- drop(not_followed_by(end))
  use value <- keep(parser)
  succeed(value)
}

pub fn drop(parser: Parser(_, a), then: fn() -> Parser(_, b)) -> Parser(_, b) {
  keep(parser, fn(_) { then() })
}

pub fn map(mapper: fn(a) -> b, parser: Parser(_, a)) -> Parser(_, b) {
  keep(parser, fn(value) { succeed(mapper(value)) })
}

pub fn any() -> Parser(_, v) {
  expect(fn(_) { True })
}

pub fn not_followed_by(parser: Parser(_, _)) -> Parser(_, Nil) {
  try(choice(drop(parser, fn() { fail(None) }), succeed(Nil)))
}

pub fn one_of(parsers: List(Parser(_, v))) -> Parser(_, v) {
  use result, parser <- list.fold_right(parsers, fail(None))
  choice(parser, result)
}

pub fn many(parser: Parser(_, v)) -> Parser(_, List(v)) {
  choice(some(parser), succeed([]))
}

pub fn some(parser: Parser(_, v)) -> Parser(_, List(v)) {
  use first <- keep(parser)
  use rest <- keep(many(parser))
  succeed([first, ..rest])
}

pub fn join(
  parser: Parser(_, List(String)),
  separator: String,
) -> Parser(_, String) {
  map(string.join(_, separator), parser)
}

pub fn grapheme(wanted: String) -> Parser(String, String) {
  use grapheme <- expect
  grapheme == wanted
}

pub fn string(wanted: String) -> Parser(String, String) {
  case string.pop_grapheme(wanted) {
    Error(Nil) -> succeed("")

    Ok(#(first, rest)) -> {
      use <- drop(grapheme(first))
      use <- drop(string(rest))
      succeed(wanted)
    }
  }
}
