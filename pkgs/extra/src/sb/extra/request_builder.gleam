import gleam/http
import gleam/http/request.{type Request}
import gleam/result
import gleam/uri.{type Uri}

// TODO: For å støtte relative URL-er i tasks.
pub type RequestBuilder(body) {
  Builder(build: fn(Uri) -> Result(Request(body), Nil))
}

pub fn new(uri: Uri) -> RequestBuilder(String) {
  use base_uri <- Builder
  use uri <- result.try(uri.merge(base_uri, uri))
  request.from_uri(uri)
}

fn map(
  builder: RequestBuilder(body),
  mapper: fn(Request(body)) -> Request(a),
) -> RequestBuilder(a) {
  use uri <- Builder
  use request <- result.map(builder.build(uri))
  mapper(request)
}

pub fn set_method(
  builder: RequestBuilder(body),
  method: http.Method,
) -> RequestBuilder(body) {
  use request <- map(builder)
  request.set_method(request, method)
}

pub fn set_body(builder: RequestBuilder(a), body: b) -> RequestBuilder(b) {
  use request <- map(builder)
  request.set_body(request, body)
}

pub fn set_header(
  builder: RequestBuilder(body),
  key: String,
  value: String,
) -> RequestBuilder(body) {
  use request <- map(builder)
  request.set_header(request, key, value)
}
