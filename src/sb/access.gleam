import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder}
import gleam/result
import sb/error.{type Error}
import sb/report.{type Report}

const access_keys = ["users", "groups", "keys"]

pub opaque type Access {
  Access(users: Users, groups: List(String), keys: List(String))
}

pub opaque type Users {
  Everyone
  Users(List(String))
}

pub opaque type Key {
  Key(id: String, secret: String)
}

pub fn key(id: String, secret: String) -> Key {
  Key(id: id, secret: secret)
}

pub fn everyone() -> Access {
  Access(users: Everyone, groups: [], keys: [])
}

pub fn none() -> Access {
  Access(users: Users([]), groups: [], keys: [])
}

pub fn decoder(dynamic: Dynamic) -> Result(Access, Report(Error)) {
  use dict <- result.try(
    decode.run(dynamic, decode.dict(decode.string, decode.dynamic))
    |> report.map_error(error.DecodeError)
    |> result.try(error.unknown_keys(_, access_keys)),
  )

  use users <- result.try(case dict.get(dict, "users") {
    Error(Nil) -> Ok(Users([]))

    Ok(dynamic) ->
      decode.run(dynamic, users_decoder())
      |> report.map_error(error.DecodeError)
      |> report.error_context(error.BadProperty("users"))
  })

  use groups <- result.try(case dict.get(dict, "groups") {
    Error(Nil) -> Ok([])

    Ok(dynamic) ->
      decode.run(dynamic, decode.list(decode.string))
      |> report.map_error(error.DecodeError)
      |> report.error_context(error.BadProperty("groups"))
  })

  use keys <- result.try(case dict.get(dict, "keys") {
    Error(Nil) -> Ok([])
    Ok(dynamic) ->
      decode.run(dynamic, decode.list(decode.string))
      |> report.map_error(error.DecodeError)
      |> report.error_context(error.BadProperty("keys"))
  })

  Ok(Access(users:, groups:, keys:))
}

fn users_decoder() -> Decoder(Users) {
  decode.one_of(decode.then(decode.string, user_decoder), [
    decode.list(decode.string) |> decode.map(Users),
  ])
}

fn user_decoder(string: String) -> Decoder(Users) {
  case string {
    "everyone" -> decode.success(Everyone)
    _string -> decode.failure(Everyone, "'everyone' or a list of users")
  }
}
