import gleam/erlang/process
import lustre/effect.{type Effect}

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
