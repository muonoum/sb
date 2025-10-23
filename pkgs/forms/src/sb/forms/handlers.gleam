import gleam/bit_array
import gleam/bytes_tree.{type BytesTree}
import gleam/http/response.{type Response}
import gleam/option.{type Option}
import sb/extra/function.{identity}
import sb/extra/report.{type Report}
import sb/extra/request_builder.{type RequestBuilder}
import sb/forms/error.{type Error}

pub type Handlers {
  Handlers(http: Http, command: Command)
}

// request, read timeout
pub type Http =
  fn(RequestBuilder(Option(BytesTree)), Int) ->
    Result(Response(BitArray), Report(Error))

// command, stdin
pub type Command =
  fn(List(String), Option(String)) -> Result(String, Report(Error))

pub fn empty() -> Handlers {
  Handlers(http: empty_http(), command: empty_command())
}

pub fn empty_http() -> Http {
  use _request, _timeout <- identity

  response.new(200)
  |> response.set_body(bit_array.from_string(""))
  |> Ok
}

pub fn empty_command() -> Command {
  use _command, _input <- identity
  Ok("")
}
