import gleam/bit_array
import gleam/bytes_tree.{type BytesTree}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/option.{type Option}
import sb/extra/report.{type Report}
import sb/forms/error.{type Error}

pub type Handlers {
  Handlers(http: Http, command: Command)
}

pub type Http =
  fn(Request(Option(BytesTree))) -> Result(Response(BitArray), Report(Error))

pub type Command =
  fn(List(String)) -> Result(BitArray, Report(Error))

pub fn empty() -> Handlers {
  Handlers(http: empty_http(), command: empty_command())
}

pub fn empty_http() -> Http {
  fn(_request) {
    Ok(
      response.new(200)
      |> response.set_body(bit_array.from_string("")),
    )
  }
}

pub fn empty_command() -> Command {
  fn(_args) { Ok(bit_array.from_string("")) }
}
