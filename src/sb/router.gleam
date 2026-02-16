import gleam/bytes_tree
import gleam/erlang/process
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/otp/actor
import gleam/otp/factory_supervisor
import gleam/string
import lustre
import lustre/effect
import lustre/element
import mist
import sb/api
import sb/component
import sb/extra/function.{identity, nil, return}
import sb/extra/reader
import sb/extra_server
import sb/forms/evaluate
import sb/forms/handlers.{type Handlers}
import sb/forms/task
import sb/frontend
import sb/frontend/components/errors as errors_component
import sb/frontend/components/task as task_component
import sb/frontend/components/tasks as tasks_component
import sb/mock
import sb/store
import wisp

pub type Runtime(message) =
  process.Subject(lustre.RuntimeMessage(message))

pub type Component(argument, message) =
  process.Name(factory_supervisor.Message(argument, Runtime(message)))

pub type ComponentBuilder(argument, message) =
  factory_supervisor.Builder(argument, Runtime(message))

pub type Components {
  Components(
    tasks: Component(Nil, tasks_component.Message),
    task: Component(Nil, task_component.Message),
    errors: Component(Nil, errors_component.Message),
  )
}

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

pub fn component_handler(
  next_router: fn(Request(_)) -> Response(_),
  components: Components,
) -> fn(Request(_)) -> Response(_) {
  use request <- identity

  case wisp.path_segments(request) {
    ["components", "tasks"] -> component_service(request, components.tasks, Nil)

    ["components", "errors"] ->
      component_service(request, components.errors, Nil)

    ["components", "task"] -> component_service(request, components.task, Nil)

    // ["components", "jobs", "requested"] -> component_service(request, todo)
    // ["components", "jobs", "started"] -> component_service(request, todo)
    // ["components", "jobs", "finished"] -> component_service(request, todo)
    _else -> next_router(request)
  }
}

pub fn tasks_component(
  store_interval store_interval: Int,
  store store: process.Subject(store.Message),
) -> ComponentBuilder(Nil, tasks_component.Message) {
  lustre.factory(
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

pub fn errors_component(
  store_interval store_interval: Int,
  store store: process.Subject(store.Message),
) -> ComponentBuilder(Nil, errors_component.Message) {
  lustre.factory(
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

pub fn task_component(
  store store: process.Subject(store.Message),
  handlers handlers: Handlers,
) -> ComponentBuilder(Nil, task_component.Message) {
  lustre.factory(
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

        let context =
          task.commands
          |> evaluate.Context(scope:, search:, handlers:, task_commands: _)

        let #(task, scope) = reader.run(context:, reader: task.step(task))
        dispatch(message(task, scope))
      },
    ),
  )
}

fn component_service(
  request: Request(mist.Connection),
  supervisor_name: Component(argument, message),
  argument: argument,
) -> Response(mist.ResponseData) {
  let supervisor = factory_supervisor.get_by_name(supervisor_name)

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
