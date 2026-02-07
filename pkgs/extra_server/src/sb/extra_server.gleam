import gleam/erlang/process
import gleam/int
import gleam/io
import lustre/effect.{type Effect}

@external(erlang, "timer", "tc")
fn timer_tc(fun: fn() -> a) -> #(Int, a)

pub fn log_duration(label: String, body: fn() -> a) -> a {
  let #(elapsed, result) = timer_tc(body)
  let ms = int.to_string(elapsed / 1000) <> "ms"
  io.println(label <> ": " <> ms)
  result
}

pub fn schedule(interval: Int, message: message) -> Effect(message) {
  use dispatch <- effect.from

  let _ = {
    use <- process.spawn
    process.sleep(interval)
    dispatch(message)
    process.send_exit(process.self())
  }

  Nil
}
