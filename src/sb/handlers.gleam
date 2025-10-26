import gleam/bit_array
import gleam/bytes_tree.{type BytesTree}
import gleam/dict
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request
import gleam/int
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, Some}
import gleam/result
import gleam/string
import gleam/uri.{type Uri, Uri}
import mug
import sb/extra/dynamic as dynamic_extra
import sb/extra/function.{identity}
import sb/extra/list as list_extra
import sb/extra/report.{type Report}
import sb/extra/request_builder.{type RequestBuilder}
import sb/extra_server/exec
import sb/extra_server/httpc
import sb/forms/command.{type Command}
import sb/forms/error.{type Error}
import sb/forms/handlers
import sb/store
import wisp

// TODO
const connect_timeout = 250

pub fn http_handler(
  base_uri: Uri,
  ca_certs ca_certs: Option(String),
) -> handlers.Http {
  use request: RequestBuilder(Option(BytesTree)), timeout: Int <- identity

  use request <- result.try(
    request.build(base_uri)
    |> report.replace_error(error.BadRequest),
  )

  let uri_string = uri.to_string(request.to_uri(request))

  wisp.log_info(
    "Handle HTTP request "
    <> uri_string
    <> " timeout="
    <> int.to_string(timeout),
  )

  let options = [
    httpc.connect_timeout(httpc.Millis(connect_timeout)),
    httpc.timeout(httpc.Millis(timeout)),
    httpc.optional(ca_certs, httpc.ca_certs),
  ]

  httpc.send(request, options)
  |> result.map_error(dynamic_extra.from)
  |> report.map_error(error.HttpError)
}

fn command_result_decoder() -> Decoder(#(Int, String)) {
  use exit_code <- decode.field("exit_code", decode.int)
  use output <- decode.field("output", decode.string)
  decode.success(#(exit_code, output))
}

pub fn command_handler(store, ca_certs ca_certs: Option(String)) {
  use command, stdin, task_commands <- identity

  wisp.log_info(
    "Handle command "
    <> string.inspect(command)
    <> option.map(stdin, fn(stdin) { " stdin=" <> stdin })
    |> option.unwrap(""),
  )

  use name, arguments <- list_extra.deconstruct(command, {
    report.error(error.BadCommand)
  })

  use command <- result.try({
    use <- result.lazy_or(
      dict.get(task_commands, name)
      |> report.replace_error(error.Todo("get command")),
    )

    store.get_command(store, name)
  })

  let arguments = list.append(command.arguments, arguments)

  wisp.log_info(
    "Using command proxy "
    <> case command.proxy {
      command.External(uri) -> uri.to_string(uri)
      command.Internal -> "internal"
    },
  )

  case command.proxy {
    command.Internal -> internal_command(command:, arguments:, stdin:)

    // TODO: socket activation -> systemd sandbox.
    command.External(uri) ->
      external_command(uri:, command:, arguments:, stdin:, ca_certs:)
  }
}

fn internal_command(
  command command: Command,
  arguments arguments: List(String),
  stdin stdin: Option(String),
) -> Result(String, Report(Error)) {
  use subject <- result.try(
    // TODO: Working directory
    exec.new(run: command.executable, with: arguments, in: ".")
    |> exec.set_stdin(stdin)
    |> exec.start_chunks
    |> report.replace_error(error.BadCommand),
  )

  case exec.collect_chunks(subject) {
    exec.Collected(exit_code: 0, stdout:, ..) -> Ok(stdout)

    exec.Collected(exit_code:, stderr:, ..) ->
      report.error(error.CommandError(exit_code:, output: stderr))
  }
}

fn external_command(
  uri uri: Uri,
  command command: Command,
  arguments arguments: List(String),
  stdin stdin: Option(String),
  ca_certs ca_certs: Option(String),
) -> Result(String, Report(Error)) {
  let stdin = {
    use stdin <- result.map(option.to_result(stdin, Nil))
    #("stdin", json.string(stdin))
  }

  let request = {
    let properties = [
      Ok(#("executable", json.string(command.executable))),
      Ok(#("arguments", json.array(arguments, json.string))),
      Ok(#("timeout", json.int(command.timeout))),
      stdin,
    ]

    list.filter_map(properties, identity)
    |> json.object
  }

  case uri {
    Uri(scheme: Some("tcp"), host: Some(host), port: Some(port), ..) ->
      tcp_command_proxy(host:, port:, request:, timeout: command.timeout)

    Uri(scheme: Some("http"), ..) | Uri(scheme: Some("https"), ..) ->
      http_command_proxy(uri:, request:, options: [
        httpc.connect_timeout(httpc.Millis(connect_timeout)),
        httpc.timeout(httpc.Millis(command.timeout)),
        httpc.optional(ca_certs, httpc.ca_certs),
      ])

    _else -> report.error(error.Todo("command proxy uri"))
  }
}

fn tcp_command_proxy(
  host host: String,
  port port: Int,
  request body: Json,
  timeout timeout: Int,
) -> Result(String, Report(Error)) {
  use socket <- result.try(
    mug.new(host, port)
    |> mug.timeout(connect_timeout)
    |> mug.connect()
    |> result.map_error(dynamic_extra.from)
    |> report.map_error(error.TcpError),
  )

  let body = bit_array.from_string(json.to_string(body))

  use _nil <- result.try(
    mug.send(socket, body)
    |> result.map_error(dynamic_extra.from)
    |> report.map_error(error.TcpError),
  )

  use response <- result.try(
    mug.receive(socket, timeout)
    |> result.map_error(dynamic_extra.from)
    |> report.map_error(error.TcpError),
  )

  use #(exit_code, output) <- result.try(
    json.parse_bits(response, command_result_decoder())
    |> report.map_error(error.JsonError),
  )

  case exit_code {
    0 -> Ok(output)
    exit_code -> report.error(error.CommandError(exit_code:, output:))
  }
}

fn http_command_proxy(
  uri uri: Uri,
  request body: Json,
  options http_options: List(fn(httpc.Config) -> httpc.Config),
) -> Result(String, Report(Error)) {
  let body = bytes_tree.from_string_tree(json.to_string_tree(body))
  use request <- result.try(
    request.from_uri(uri)
    |> report.replace_error(error.Todo("request from uri")),
  )

  let request =
    request
    |> request.set_method(http.Post)
    |> request.set_body(Some(body))

  use response <- result.try(
    httpc.send(request, http_options)
    |> result.map_error(dynamic_extra.from)
    |> report.map_error(error.HttpError),
  )

  use #(exit_code, output) <- result.try(
    json.parse_bits(response.body, command_result_decoder())
    |> report.map_error(error.JsonError),
  )

  case exit_code {
    0 -> Ok(output)
    exit_code -> report.error(error.CommandError(exit_code:, output:))
  }
}
