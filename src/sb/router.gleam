import gleam/bytes_tree
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/otp/actor
import gleam/otp/factory_supervisor
import gleam/string
import lustre/element
import mist
import sb/api
import sb/component
import sb/components.{type Component, type Components}
import sb/extra/function.{identity}
import sb/frontend
import sb/mock
import wisp

pub fn service(
  request: wisp.Request,
  serve_static: fn(wisp.Request, fn() -> wisp.Response) -> wisp.Response,
) -> wisp.Response {
  use <- wisp.rescue_crashes
  use csp_nonce <- wisp.content_security_policy_protection()
  use <- serve_static(request)
  use <- wisp.log_request(request)

  case request.method, wisp.path_segments(request) {
    _method, ["mock", ..segments] -> mock.service(request, segments)
    _method, ["api", ..segments] -> api.service(request, segments)
    http.Get, [] -> wisp.redirect("/oppgaver")

    _method, _segments ->
      wisp.html_body(
        wisp.ok(),
        element.to_document_string(frontend.page(csp_nonce)),
      )
  }
}

// TODO: Flytt inn i den vanlige ruteren når wisp får websocket-støtte
pub fn component_handler(
  next_router: fn(Request(_)) -> Response(_),
  components: Components,
) -> fn(Request(_)) -> Response(_) {
  use request <- identity

  case wisp.path_segments(request) {
    ["components", "tasks"] -> component_service(request, components.tasks, Nil)

    // TODO: Denne avslutter når vi laster /oppgaver direkte, men funker hvis vi navigerer
    // tilbake til /oppgaver fra f.eks. /oppgave/[..]
    ["components", "errors"] ->
      component_service(request, components.errors, Nil)

    ["components", "task"] -> component_service(request, components.task, Nil)

    // ["components", "jobs", "requested"] -> component_service(request, todo)
    // ["components", "jobs", "started"] -> component_service(request, todo)
    // ["components", "jobs", "finished"] -> component_service(request, todo)
    _else -> next_router(request)
  }
}

fn component_service(
  request: Request(mist.Connection),
  component: Component(argument, message),
  argument: argument,
) -> Response(mist.ResponseData) {
  let supervisor = factory_supervisor.get_by_name(component)

  case factory_supervisor.start_child(supervisor, argument) {
    Ok(actor.Started(pid: _, data: component)) ->
      component.service(request, component)

    Error(error) -> {
      let message = ["Server component", request.path, string.inspect(error)]
      wisp.log_error(string.join(message, ": "))

      response.new(500)
      |> response.set_body(mist.Bytes(bytes_tree.new()))
    }
  }
}
