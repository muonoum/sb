import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/option.{type Option, Some}
import gleam/string
import lustre
import lustre/server_component as server
import mist
import wisp

pub fn service(
  component: lustre.Runtime(message),
  request: Request(mist.Connection),
) -> Response(mist.ResponseData) {
  let on_init = on_init(_, request, component)
  mist.websocket(request:, on_init:, on_close:, handler:)
}

type State(message) {
  State(
    request: Request(mist.Connection),
    component: lustre.Runtime(message),
    subject: process.Subject(server.ClientMessage(message)),
  )
}

fn on_init(
  _connection: mist.WebsocketConnection,
  request: Request(mist.Connection),
  component: lustre.Runtime(message),
) -> #(State(message), Option(process.Selector(server.ClientMessage(message)))) {
  wisp.log_info("Join " <> request.path)
  let subject = process.new_subject()
  let selector = process.new_selector() |> process.select(subject)
  server.register_subject(subject) |> lustre.send(to: component)
  #(State(request:, component:, subject:), Some(selector))
}

fn on_close(state: State(message)) -> Nil {
  wisp.log_info("Leave " <> state.request.path)
  deregister(state)
}

fn handler(
  state: State(message),
  message: mist.WebsocketMessage(server.ClientMessage(message)),
  connection: mist.WebsocketConnection,
) -> mist.Next(State(message), server.ClientMessage(message)) {
  case message {
    mist.Closed | mist.Shutdown -> stop(state)
    mist.Binary(_) -> mist.continue(state)
    mist.Text(text) -> runtime_message(text, state)
    mist.Custom(message) -> client_message(connection, message, state)
  }
}

fn runtime_message(
  text: String,
  state: State(message),
) -> mist.Next(State(message), server.ClientMessage(message)) {
  case json.parse(text, server.runtime_message_decoder()) {
    Error(error) -> decode_error(state.request.path, text, error)
    Ok(message) -> lustre.send(state.component, message)
  }

  mist.continue(state)
}

fn client_message(connection, message, state: State(message)) {
  let json = json.to_string(server.client_message_to_json(message))

  case mist.send_text_frame(connection, json) {
    Error(error) -> send_error(state.request.path, error)
    Ok(_) -> Nil
  }

  mist.continue(state)
}

fn stop(
  state: State(message),
) -> mist.Next(State(message), server.ClientMessage(message)) {
  deregister(state)
  mist.stop()
}

fn deregister(state: State(message)) -> Nil {
  server.deregister_subject(state.subject)
  |> lustre.send(to: state.component)
}

fn decode_error(path: String, text: String, error: any) -> Nil {
  ["Decode runtime message", path, text, string.inspect(error)]
  |> string.join(": ")
  |> wisp.log_error
}

fn send_error(path: String, error: any) -> Nil {
  ["Send client message", path, string.inspect(error)]
  |> string.join(": ")
  |> wisp.log_error
}
