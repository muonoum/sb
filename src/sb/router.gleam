import gleam/bytes_tree
import gleam/erlang/process
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/string
import lustre
import lustre/effect
import lustre/element
import mist
import sb/api
import sb/component
import sb/extra/function.{identity}
import sb/extra_erlang
import sb/frontend
import sb/frontend/components/errors
import sb/frontend/components/task
import sb/frontend/components/tasks
import sb/store
import wisp

pub fn service(
  request: wisp.Request,
  serve_static: fn(wisp.Request, fn() -> wisp.Response) -> wisp.Response,
) -> wisp.Response {
  use <- wisp.rescue_crashes
  use <- serve_static(request)
  use <- wisp.log_request(request)

  case request.method, wisp.path_segments(request) {
    _method, ["api", ..] -> api.service(request)
    http.Get, [] -> wisp.redirect("/oppgaver")
    _method, _segments ->
      wisp.html_body(wisp.ok(), element.to_document_string(frontend.page()))
  }
}

pub fn websocket_router(
  next_router: fn(Request(_)) -> Response(_),
  store_interval store_interval: Int,
  store store: process.Subject(store.Message),
) -> fn(Request(_)) -> Response(_) {
  use request <- identity

  case wisp.path_segments(request) {
    ["components", "errors"] ->
      component_service(
        request,
        errors.app(
          schedule: extra_erlang.schedule(store_interval, _),
          load: fn(message) {
            use dispatch <- effect.from
            dispatch(message(store.get_errors(store)))
          },
        ),
      )

    ["components", "tasks"] ->
      component_service(
        request,
        tasks.app(
          schedule: extra_erlang.schedule(store_interval, _),
          load: fn(message) {
            use dispatch <- effect.from
            dispatch(message(store.get_tasks(store)))
          },
        ),
      )

    ["components", "task"] ->
      component_service(
        request,
        task.app(
          schedule: extra_erlang.schedule,
          load: fn(task_id, message) {
            use dispatch <- effect.from
            dispatch(message(store.get_task(store, task_id)))
          },
          step: fn(_task, _search, _message) {
            use _dispatch <- effect.from
            todo
          },
        ),
      )

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
