import gleam/bit_array
import gleam/bytes_tree.{type BytesTree}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/option.{type Option}
import sb/error.{type Error}
import sb/report.{type Report}

pub type Http =
  fn(Request(Option(BytesTree))) -> Result(Response(BitArray), Report(Error))

pub type Handlers {
  Handlers(http: Http)
}

pub fn empty() -> Handlers {
  Handlers(http: empty_http())
}

pub fn empty_http() -> Http {
  fn(_request) {
    Ok(
      response.new(200)
      |> response.set_body(bit_array.from_string("")),
    )
  }
}
