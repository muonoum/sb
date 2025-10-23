import gleam/erlang/process
import gleam/int
import gleam/io
import gleam_community/ansi
import sb/extra_server/exec

pub fn main() {
  let assert Ok(chunks) =
    exec.new(run: "/usr/bin/find", with: ["."], in: ".")
    |> exec.start_chunks

  printer(chunks)
}

fn printer(subject: process.Subject(exec.Output)) -> Nil {
  case process.receive_forever(subject) {
    exec.Exit(exit_code) ->
      io.println(ansi.magenta("==> exit-code " <> int.to_string(exit_code)))

    exec.Stdout(line) -> {
      io.println(line)
      printer(subject)
    }

    exec.Stderr(data) -> {
      io.println_error(data)
      printer(subject)
    }
  }
}
