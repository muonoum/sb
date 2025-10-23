import gleam/erlang/process
import gleeunit/should
import sb/extra_server/process as process_extra

pub fn async_await_test() {
  process_extra.async(fn() { process.sleep(100) })
  |> process_extra.await(timeout: 50)
  |> should.be_error

  process_extra.async(fn() { process.sleep(100) })
  |> process_extra.await(timeout: 150)
  |> should.be_ok
}
