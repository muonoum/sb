import gleam/bool
import gleam/erlang/process.{type Pid, type Subject}
import gleam/result

pub opaque type Task(v) {
  Task(subject: Subject(v), owner: Pid, pid: Pid)
}

pub fn async(work: fn() -> v) -> Task(v) {
  let subject = process.new_subject()
  let owner = process.self()
  let pid = process.spawn(fn() { process.send(subject, work()) })
  Task(subject:, owner:, pid:)
}

pub fn await(task: Task(v), timeout timeout: Int) -> Result(v, Nil) {
  use <- bool.guard(task.owner != process.self(), Error(Nil))
  use v <- result.try(process.receive(task.subject, timeout))
  Ok(v)
}

pub fn await_forever(task: Task(v)) -> Result(v, Nil) {
  use <- bool.guard(task.owner != process.self(), Error(Nil))
  let v = process.receive_forever(task.subject)
  Ok(v)
}
