import gleam/bytes_tree
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/string
import lustre
import lustre/element
import mist
import sb/component
import sb/extra
import sb/frontend
import wisp

pub fn service(
  request: wisp.Request,
  serve_static: fn(wisp.Request, fn() -> wisp.Response) -> wisp.Response,
) -> wisp.Response {
  use <- wisp.rescue_crashes
  use <- serve_static(request)
  use <- wisp.log_request(request)

  case request.method, wisp.path_segments(request) {
    http.Get, [] -> wisp.redirect("/oppgaver")

    _method, _segments ->
      wisp.html_body(wisp.ok(), element.to_document_string(frontend.page()))
  }
}

pub fn websocket_router(
  next_router: fn(Request(_)) -> Response(_),
) -> fn(Request(_)) -> Response(_) {
  use request <- extra.identity

  case wisp.path_segments(request) {
    ["components", "tasks"] -> component_service(request, todo)
    ["components", "task"] -> component_service(request, todo)
    ["components", "jobs", "requested"] -> component_service(request, todo)
    ["components", "jobs", "started"] -> component_service(request, todo)
    ["components", "jobs", "finished"] -> component_service(request, todo)
    _else -> next_router(request)
  }
}

fn component_service(
  request: Request(mist.Connection),
  app: lustre.App(Nil, model, message),
) -> Response(mist.ResponseData) {
  case lustre.start_server_component(app, Nil) {
    Ok(component) -> component.service(component, request)

    Error(error) -> {
      let message = ["Serve component", request.path, string.inspect(error)]
      wisp.log_error(string.join(message, ": "))

      response.new(500)
      |> response.set_body(mist.Bytes(bytes_tree.new()))
    }
  }
}
