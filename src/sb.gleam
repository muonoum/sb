import envoy
import filepath
import gleam/erlang/application
import gleam/erlang/process
import gleam/int
import gleam/option
import gleam/otp/factory_supervisor as factory
import gleam/otp/static_supervisor.{type Supervisor} as supervisor
import gleam/otp/supervision.{type ChildSpecification}
import gleam/result
import gleam/uri
import lustre
import lustre/effect
import mist
import sb/extra/function.{identity, nil, return}
import sb/extra/reader
import sb/extra_server
import sb/forms/evaluate
import sb/forms/handlers.{type Handlers, Handlers} as _
import sb/forms/task
import sb/frontend/components/errors as errors_component
import sb/frontend/components/task as task_component
import sb/frontend/components/tasks as tasks_component
import sb/handlers
import sb/router
import sb/store
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()

  let assert Ok(priv_directory) = application.priv_directory("sb")

  let store_prefix = {
    use <- result.lazy_unwrap(envoy.get("STORE_PREFIX"))
    filepath.join(priv_directory, "sb")
  }

  let assert Ok(store_interval) = case envoy.get("STORE_INTERVAL") {
    Ok(interval) -> result.map(int.parse(interval), int.max(1000, _))
    Error(Nil) -> Ok(2500)
  }
    as "STORE_INTERVAL"

  let assert Ok(base_uri) = {
    use uri_string <- result.try(envoy.get("BASE_URI"))
    uri.parse(uri_string)
  }
    as "BASE_URI"

  let http_address = result.unwrap(envoy.get("HTTP_ADDRESS"), "localhost")
  let assert Ok(http_port) = result.try(envoy.get("HTTP_PORT"), int.parse)
    as "HTTP_PORT"

  let secret_key_base = {
    use <- result.lazy_unwrap(envoy.get("SECRET_KEY_BASE"))
    wisp.random_string(64)
  }

  let ca_certs =
    envoy.get("CA_CERTS")
    |> option.from_result

  let store_name = process.new_name("store")
  let store = process.named_subject(store_name)

  let store_spec =
    store.supervised(store_name, {
      store.Config(
        prefix: store_prefix,
        interval: store_interval,
        pattern: "**/*.yaml",
      )
    })

  let handlers = {
    let http = handlers.http_handler(base_uri, ca_certs)
    let command = handlers.command_handler(store, ca_certs)
    Handlers(http:, command:)
  }

  let components =
    router.Components(
      tasks: process.new_name("tasks"),
      errors: process.new_name("errors"),
      task: process.new_name("task"),
    )

  let components_spec =
    components_supervisor(components:, store:, store_interval:, handlers:)

  let server_spec =
    router.service(_, static_handler(priv_directory))
    |> wisp_mist.handler(secret_key_base)
    |> router.component_handler(components)
    |> mist.new
    |> mist.bind(http_address)
    |> mist.port(http_port)
    |> mist.supervised

  let assert Ok(_) =
    supervisor.start({
      supervisor.new(supervisor.OneForOne)
      |> supervisor.add(store_spec)
      |> supervisor.add(components_spec)
      |> supervisor.add(server_spec)
    })

  process.sleep_forever()
}

fn static_handler(
  priv_directory: String,
) -> fn(wisp.Request, fn() -> wisp.Response) -> wisp.Response {
  let sb = filepath.join(priv_directory, "static")

  let assert Ok(lustre) =
    application.priv_directory("lustre")
    |> result.map(filepath.join(_, "static"))
    as "lustre/static"

  let assert Ok(lustre_portal) =
    application.priv_directory("lustre_portal")
    |> result.map(filepath.join(_, "static"))
    as "lustre_portal/static"

  use request, then <- identity

  use <- wisp.serve_static(request, under: "/", from: sb)
  use <- wisp.serve_static(request, under: "/lustre", from: lustre)
  use <- wisp.serve_static(request, under: "/lustre", from: lustre_portal)

  then()
}

fn components_supervisor(
  components components: router.Components,
  store store: process.Subject(store.Message),
  store_interval store_interval: Int,
  handlers handlers: Handlers,
) -> ChildSpecification(Supervisor) {
  let tasks_spec =
    tasks_component(store:, store_interval:)
    |> lustre.factory
    |> factory.named(components.tasks)
    |> factory.supervised

  let errors_spec =
    errors_component(store:, store_interval:)
    |> lustre.factory
    |> factory.named(components.errors)
    |> factory.supervised

  let task_spec =
    task_component(store:, handlers:)
    |> lustre.factory
    |> factory.named(components.task)
    |> factory.supervised

  supervisor.new(supervisor.OneForOne)
  |> supervisor.add(tasks_spec)
  |> supervisor.add(errors_spec)
  |> supervisor.add(task_spec)
  |> supervisor.supervised
}

fn tasks_component(
  store store: process.Subject(store.Message),
  store_interval store_interval: Int,
) -> lustre.App(Nil, tasks_component.Model, tasks_component.Message) {
  tasks_component.app(
    schedule: extra_server.schedule(store_interval, _),
    load: fn(message: tasks_component.LoadMessage) {
      use dispatch <- effect.from
      let tasks = store.get_tasks(store)
      dispatch(message(tasks))
    },
  )
}

fn errors_component(
  store store: process.Subject(store.Message),
  store_interval store_interval: Int,
) -> lustre.App(Nil, errors_component.Model, errors_component.Message) {
  errors_component.app(
    schedule: extra_server.schedule(store_interval, _),
    load: fn(message: errors_component.LoadMessage) {
      use dispatch <- effect.from
      let reports = store.get_reports(store)
      dispatch(message(reports))
    },
  )
}

fn task_component(
  store store: process.Subject(store.Message),
  handlers handlers: Handlers,
) -> lustre.App(Nil, task_component.Model, task_component.Message) {
  task_component.app(
    schedule: extra_server.schedule,
    load: fn(task_id, message: task_component.LoadMessage) {
      use dispatch <- effect.from
      let task = store.get_task(store, task_id)
      dispatch(message(task))
    },
    // TODO: Avbryte ved reload/navigering
    step: fn(task, scope, search, message: task_component.StepMessage) {
      use dispatch <- effect.from
      use <- return(nil)
      use <- process.spawn_unlinked

      let #(task, scope) =
        task.commands
        |> evaluate.Context(scope:, search:, handlers:, task_commands: _)
        |> reader.run(context: _, reader: task.step(task))

      dispatch(message(task, scope))
    },
  )
}
