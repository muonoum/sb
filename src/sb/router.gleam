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
import sb/extra/function.{identity, nil, return}
import sb/extra_server
import sb/forms/handlers.{type Handlers}
import sb/forms/task
import sb/frontend
import sb/frontend/components/errors as errors_component
import sb/frontend/components/task as task_component
import sb/frontend/components/tasks as tasks_component
import sb/mock
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
    _method, ["mock", ..segments] -> mock.service(request, segments)
    _method, ["api", ..segments] -> api.service(request, segments)
    http.Get, [] -> wisp.redirect("/oppgaver")

    _method, _segments ->
      wisp.html_body(wisp.ok(), element.to_document_string(frontend.page()))
  }
}

pub fn components(
  next_router: fn(Request(_)) -> Response(_),
  store_interval store_interval: Int,
  store store: process.Subject(store.Message),
  handlers handlers: Handlers,
) -> fn(Request(_)) -> Response(_) {
  use request <- identity

  case wisp.path_segments(request) {
    ["components", "tasks"] -> tasks_component(request, store_interval, store)
    ["components", "errors"] -> errors_component(request, store_interval, store)
    ["components", "task"] -> task_component(request, store, handlers)
    // ["components", "jobs", "requested"] -> component_service(request, todo)
    // ["components", "jobs", "started"] -> component_service(request, todo)
    // ["components", "jobs", "finished"] -> component_service(request, todo)
    _else -> next_router(request)
  }
}

fn tasks_component(
  request: Request(mist.Connection),
  store_interval: Int,
  store: process.Subject(store.Message),
) -> Response(mist.ResponseData) {
  component_service(
    request,
    tasks_component.app(
      schedule: extra_server.schedule(store_interval, _),
      load: fn(message: tasks_component.LoadMessage) {
        use dispatch <- effect.from
        let tasks = store.get_tasks(store)
        dispatch(message(tasks))
      },
    ),
  )
}

fn errors_component(
  request: Request(mist.Connection),
  store_interval: Int,
  store: process.Subject(store.Message),
) -> Response(mist.ResponseData) {
  component_service(
    request,
    errors_component.app(
      schedule: extra_server.schedule(store_interval, _),
      load: fn(message: errors_component.LoadMessage) {
        use dispatch <- effect.from
        let reports = store.get_reports(store)
        dispatch(message(reports))
      },
    ),
  )
}

fn task_component(
  request: Request(mist.Connection),
  store: process.Subject(store.Message),
  handlers: Handlers,
) -> Response(mist.ResponseData) {
  component_service(
    request,
    task_component.app(
      schedule: extra_server.schedule,
      load: fn(task_id, message: task_component.LoadMessage) {
        use dispatch <- effect.from
        let task = store.get_task(store, task_id)
        dispatch(message(task))
      },
      step: fn(task, scope, search, message: task_component.StepMessage) {
        // TODO: Avbryte ved reload/navigering
        use dispatch <- effect.from
        use <- return(nil)
        use <- process.spawn_unlinked
        let #(task, scope) = task.step(task, scope, search:, handlers:)
        dispatch(message(task, scope))
      },
    ),
  )
}

fn component_service(
  request: Request(mist.Connection),
  app: lustre.App(Nil, model, message),
) -> Response(mist.ResponseData) {
  case lustre.start_server_component(app, Nil) {
    Ok(component) -> component.service(component, request)

    Error(error) -> {
      let message = ["Server component", request.path, string.inspect(error)]
      wisp.log_error(string.join(message, ": "))

      response.new(500)
      |> response.set_body(mist.Bytes(bytes_tree.new()))
    }
  }
}
