import gleam/bool
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/erlang/atom
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/option.{type Option}
import gleam/otp/actor
import gleam/result
import gleam/string
import splitter.{type Splitter}

const start_timeout = 1000

pub type Command {
  Command(
    executable: String,
    arguments: List(String),
    directory: String,
    stdin: Option(String),
  )
}

pub fn new(
  run executable: String,
  with arguments: List(String),
  in directory: String,
) -> Command {
  Command(executable:, arguments:, directory:, stdin: option.None)
}

pub fn set_stdin(command: Command, stdin: Option(String)) -> Command {
  Command(..command, stdin:)
}

type OsPid

@external(erlang, "glue", "find_executable")
pub fn find_executable(name: String) -> Result(String, Nil)

@external(erlang, "glue", "exec_run_link")
fn exec_run_link(command: Command) -> Result(#(process.Pid, OsPid), Dynamic)

@external(erlang, "exec", "status")
fn exec_status(status: any) -> Int

pub type Output {
  Stdout(String)
  Stderr(String)
  Exit(Int)
}

pub type Collected(v) {
  Collected(stdout: v, stderr: String, exit_code: Int)
}

type Chunks {
  Chunks(return: Subject(Output))
}

type Message {
  GotStdout(String)
  GotStderr(String)
  CommandExited(process.ExitMessage)
  DecodingFailed(List(decode.DecodeError))
}

pub fn chunks(command: Command) -> Result(Collected(String), String) {
  start_chunks(command)
  |> result.map(collect_chunks)
}

pub fn collect_chunks(subject: Subject(Output)) -> Collected(String) {
  collect_chunks_loop(subject, stdout: [], stderr: [])
}

fn collect_chunks_loop(
  subject: Subject(Output),
  stdout stdout: List(String),
  stderr stderr: List(String),
) -> Collected(String) {
  case process.receive_forever(subject) {
    Stdout(data) -> collect_chunks_loop(subject, [data, ..stdout], stderr)
    Stderr(data) -> collect_chunks_loop(subject, stdout, [data, ..stderr])

    Exit(exit_code) ->
      Collected(
        stdout: string.join(list.reverse(stdout), ""),
        stderr: string.join(list.reverse(stderr), ""),
        exit_code:,
      )
  }
}

pub fn start_chunks(command: Command) -> Result(Subject(Output), String) {
  let subject = process.new_subject()

  let started =
    actor.new_with_initialiser(start_timeout, init_chunks(_, command, subject))
    |> actor.on_message(update_chunks)
    |> actor.start

  case started {
    Error(actor.InitFailed(error)) -> Error(error)
    Error(actor.InitTimeout) -> Error("init timed out")
    Error(actor.InitExited(exited)) -> Error(string.inspect(exited))
    Ok(started) -> Ok(started.data)
  }
}

fn init_chunks(
  subject: Subject(Message),
  command: Command,
  return: Subject(Output),
) -> Result(actor.Initialised(Chunks, Message, Subject(Output)), String) {
  process.trap_exits(True)

  case exec_run_link(command) {
    Error(dynamic) -> Error(string.inspect(dynamic))

    Ok(#(_pid, _os_pid)) -> {
      let stdout = atom.create("stdout")
      let stderr = atom.create("stderr")

      let selector =
        process.new_selector()
        |> process.select(subject)
        |> process.select_record(stdout, 2, decode_output(_, GotStdout))
        |> process.select_record(stderr, 2, decode_output(_, GotStderr))
        |> process.select_trapped_exits(CommandExited)

      actor.initialised(Chunks(return:))
      |> actor.selecting(selector)
      |> actor.returning(return)
      |> Ok
    }
  }
}

fn update_chunks(model: Chunks, message: Message) -> actor.Next(Chunks, Message) {
  case message {
    GotStdout(chunk) -> {
      process.send(model.return, Stdout(chunk))
      actor.continue(model)
    }

    GotStderr(chunk) -> {
      process.send(model.return, Stderr(chunk))
      actor.continue(model)
    }

    CommandExited(process.ExitMessage(reason:, ..)) -> exited(model, reason)

    DecodingFailed(_errors) -> {
      process.send(model.return, Exit(1))
      actor.stop_abnormal("decode error")
    }
  }
}

fn exited(
  model: Chunks,
  reason: process.ExitReason,
) -> actor.Next(Chunks, Message) {
  case reason {
    process.Normal -> {
      process.send(model.return, Exit(0))
      actor.stop()
    }

    process.Killed -> {
      process.send(model.return, Exit(1))
      actor.stop_abnormal("killed")
    }

    process.Abnormal(reason:) ->
      case decode.run(reason, exit_decoder()) {
        Error(_error) -> {
          process.send(model.return, Exit(1))
          actor.stop_abnormal("exit_code decode error")
        }

        Ok(exit_code) -> {
          process.send(model.return, Exit(exit_code))
          actor.stop_abnormal("bad exit_code")
        }
      }
  }
}

fn decode_output(dynamic: Dynamic, message: fn(String) -> Message) -> Message {
  case decode.run(dynamic, decode.at([2], decode.string)) {
    Error(errors) -> DecodingFailed(errors)
    Ok(output) -> message(output)
  }
}

fn exit_decoder() -> decode.Decoder(Int) {
  use tag <- decode.field(0, atom.decoder())
  let exit_status = atom.create("exit_status")

  use <- bool.lazy_guard(tag == exit_status, fn() {
    decode.map(decode.at([1], decode.int), exec_status)
  })

  decode.failure(1, "exit_status")
}

type Lines {
  Lines(return: Subject(Output), splitter: Splitter, continuation: String)
}

pub fn lines(command: Command) -> Result(Collected(List(String)), String) {
  start_lines(command)
  |> result.map(collect_lines)
}

pub fn collect_lines(subject: Subject(Output)) -> Collected(List(String)) {
  collect_lines_loop(subject, stdout: [], stderr: [])
}

fn collect_lines_loop(
  subject: Subject(Output),
  stdout stdout: List(String),
  stderr stderr: List(String),
) -> Collected(List(String)) {
  case process.receive_forever(subject) {
    Stdout(data) -> collect_lines_loop(subject, [data, ..stdout], stderr)
    Stderr(data) -> collect_lines_loop(subject, stdout, [data, ..stderr])

    Exit(exit_code) ->
      Collected(
        exit_code:,
        stdout: list.reverse(stdout),
        stderr: string.join(list.reverse(stderr), ""),
      )
  }
}

pub fn start_lines(command: Command) -> Result(Subject(Output), String) {
  let subject = process.new_subject()

  let started =
    actor.new_with_initialiser(start_timeout, init_lines(_, command, subject))
    |> actor.on_message(update_lines)
    |> actor.start

  case started {
    Error(actor.InitFailed(error)) -> Error(error)
    Error(actor.InitTimeout) -> Error("init timed out")
    Error(actor.InitExited(exited)) -> Error(string.inspect(exited))
    Ok(started) -> Ok(started.data)
  }
}

fn init_lines(
  _subject,
  command: Command,
  return: Subject(Output),
) -> Result(actor.Initialised(Lines, Output, Subject(Output)), String) {
  use chunks <- result.try(start_chunks(command))
  let splitter = splitter.new(["\n", "\r\n"])

  let selector =
    process.new_selector()
    |> process.select(chunks)

  Lines(return:, splitter:, continuation: "")
  |> actor.initialised
  |> actor.selecting(selector)
  |> actor.returning(return)
  |> Ok
}

fn update_lines(model: Lines, message: Output) -> actor.Next(Lines, Output) {
  case message {
    Stdout(chunk) -> {
      let #(lines, continuation) =
        split_chunk(model.splitter, chunk, [])
        |> continue_line(model.continuation)

      list.map(lines, Stdout)
      |> list.each(process.send(model.return, _))

      actor.continue(Lines(..model, continuation:))
    }

    Stderr(output) -> {
      process.send(model.return, Stderr(output))
      actor.continue(model)
    }

    Exit(exit_code) -> {
      case model.continuation {
        "" -> process.send(model.return, Exit(exit_code))

        continuation -> {
          process.send(model.return, Stdout(continuation))
          process.send(model.return, Exit(exit_code))
        }
      }

      actor.stop()
    }
  }
}

fn split_chunk(
  splitter: Splitter,
  chunk: String,
  results: List(String),
) -> #(List(String), String) {
  case splitter.split(splitter, chunk) {
    #(prefix, "", "") -> #(list.reverse(results), prefix)

    #(prefix, _delimiter, suffix) ->
      split_chunk(splitter, suffix, [prefix, ..results])
  }
}

fn continue_line(
  split: #(List(String), String),
  continuation: String,
) -> #(List(String), String) {
  case split {
    #([], rest) -> #([continuation <> rest], "")
    #([line, ..lines], rest) -> #([continuation <> line, ..lines], rest)
  }
}
