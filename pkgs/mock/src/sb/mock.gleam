import blah/lorem
import gleam/erlang/process
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import wisp

pub fn service(request: Request(_), segments: List(String)) -> wisp.Response {
  case request.method, segments {
    http.Post, ["echo"] -> {
      use body <- wisp.require_string_body(request)
      use <- delayed_response(request)
      wisp.string_body(wisp.ok(), body)
    }

    http.Get, ["lorem", "sentences", min, max] ->
      case int.parse(min), int.parse(max) {
        Ok(min), Ok(max) -> {
          use <- delayed_response(request)
          lorem_sentences(min, max)
          |> json.array(json.string)
          |> json.to_string
          |> wisp.json_response(200)
        }

        _min, _max -> wisp.bad_request("Bad parameters")
      }

    _method, _segments -> wisp.not_found()
  }
}

pub fn delayed_response(
  request: Request(_),
  then: fn() -> Response(_),
) -> Response(_) {
  process.sleep(
    wisp.get_query(request)
    |> list.key_find("delay")
    |> result.try(int.parse)
    |> result.unwrap(0),
  )

  then()
}

pub fn lorem_sentences(min: Int, max: Int) -> List(String) {
  int.random(max)
  |> int.clamp(min, max)
  |> list.range(1, _)
  |> list.map(fn(_) { lorem.sentence() })
}
