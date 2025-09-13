import envoy
import filepath
import gleam/erlang/application
import gleam/erlang/process
import gleam/int
import gleam/otp/static_supervisor as supervisor
import gleam/result
import mist
import sb/extra/function.{identity}
import sb/router
import sb/task_store
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()

  let assert Ok(priv_directory) = application.priv_directory("sb")

  let store_prefix = {
    use <- result.lazy_unwrap(envoy.get("STORE_PREFIX"))
    filepath.join(priv_directory, "sb")
  }

  let assert Ok(store_interval) = {
    case envoy.get("STORE_INTERVAL") {
      Ok(interval) -> result.map(int.parse(interval), int.max(1000, _))
      Error(Nil) -> Ok(2500)
    }
  }

  let task_store_name = process.new_name("task_store")
  let task_store = process.named_subject(task_store_name)

  let task_store_spec =
    task_store.supervised(
      task_store_name,
      task_store.Config(
        prefix: store_prefix,
        interval: store_interval,
        pattern: "**/*.yaml",
      ),
    )

  let static_handler = {
    let sb = filepath.join(priv_directory, "static")

    let assert Ok(lustre) =
      application.priv_directory("lustre")
      |> result.map(filepath.join(_, "static"))

    let assert Ok(lustre_portal) =
      application.priv_directory("lustre_portal")
      |> result.map(filepath.join(_, "static"))

    use request, next <- identity

    use <- wisp.serve_static(request, under: "/", from: sb)
    use <- wisp.serve_static(request, under: "/lustre", from: lustre)
    use <- wisp.serve_static(request, under: "/lustre", from: lustre_portal)

    next()
  }

  let http_address = result.unwrap(envoy.get("HTTP_ADDRESS"), "localhost")
  let assert Ok(http_port) = result.try(envoy.get("HTTP_PORT"), int.parse)

  let secret_key_base = {
    use <- result.lazy_unwrap(envoy.get("SECRET_KEY_BASE"))
    wisp.random_string(64)
  }

  let http_server_spec =
    router.service(_, static_handler)
    |> wisp_mist.handler(secret_key_base)
    |> router.websocket_router(store_interval:, task_store:)
    |> mist.new
    |> mist.bind(http_address)
    |> mist.port(http_port)
    |> mist.supervised

  let assert Ok(_) =
    supervisor.start({
      supervisor.new(supervisor.OneForOne)
      |> supervisor.add(http_server_spec)
      |> supervisor.add(task_store_spec)
    })

  process.sleep_forever()
}
