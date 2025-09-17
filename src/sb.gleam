import envoy
import filepath
import gleam/erlang/application
import gleam/erlang/process
import gleam/int
import gleam/otp/static_supervisor as supervisor
import gleam/result
import mist
import sb/extra/dynamic as dynamic_extra
import sb/extra/function.{identity}
import sb/extra/report
import sb/extra_server/httpc
import sb/forms/error
import sb/forms/handlers.{Handlers}
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

  let assert Ok(store_interval) = {
    case envoy.get("STORE_INTERVAL") {
      Ok(interval) -> result.map(int.parse(interval), int.max(1000, _))
      Error(Nil) -> Ok(2500)
    }
  }

  let store_name = process.new_name("store")

  let store_spec =
    store.supervised(
      store_name,
      store.Config(
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

  let httpc_options = {
    case envoy.get("CA_CERTS") {
      Ok(ca_certs) -> [httpc.ca_certs(ca_certs)]
      Error(Nil) -> []
    }
  }

  let handlers = {
    let command = handlers.empty_command()

    let http = fn(request) {
      httpc.send(request, httpc_options)
      |> result.map_error(dynamic_extra.from)
      |> report.map_error(error.HttpError)
    }

    Handlers(command:, http:)
  }

  let store = process.named_subject(store_name)

  let server_spec =
    router.service(_, static_handler)
    |> wisp_mist.handler(secret_key_base)
    |> router.websocket_router(store_interval:, store:, handlers:)
    |> mist.new
    |> mist.bind(http_address)
    |> mist.port(http_port)
    |> mist.supervised

  let assert Ok(_) =
    supervisor.start({
      supervisor.new(supervisor.OneForOne)
      |> supervisor.add(server_spec)
      |> supervisor.add(store_spec)
    })

  process.sleep_forever()
}
