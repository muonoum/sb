import envoy
import filepath
import gleam/erlang/application
import gleam/erlang/process
import gleam/int
import gleam/option
import gleam/otp/factory_supervisor
import gleam/otp/static_supervisor as supervisor
import gleam/result
import gleam/uri
import mist
import sb/extra/function.{identity}
import sb/forms/handlers.{Handlers} as _
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

  let tasks_component_name = process.new_name("tasks_component")
  let task_component_name = process.new_name("task_component")
  let errors_component_name = process.new_name("errors_component")

  let tasks_component =
    router.tasks_component(store:, store_interval:)
    |> factory_supervisor.named(tasks_component_name)
    |> factory_supervisor.supervised

  let task_component =
    router.task_component(store:, handlers:)
    |> factory_supervisor.named(task_component_name)
    |> factory_supervisor.supervised

  let errors_component =
    router.errors_component(store:, store_interval:)
    |> factory_supervisor.named(errors_component_name)
    |> factory_supervisor.supervised

  let components =
    router.Components(
      tasks: tasks_component_name,
      task: task_component_name,
      errors: errors_component_name,
    )

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
      |> supervisor.add(server_spec)
      |> supervisor.add(store_spec)
      |> supervisor.add(tasks_component)
      |> supervisor.add(task_component)
      |> supervisor.add(errors_component)
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
