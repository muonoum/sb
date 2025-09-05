import extra
import extra/state
import gleam/dynamic/decode.{type Decoder}
import sb/decoder
import sb/props.{type Props}
import sb/zero.{type Zero}

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

pub fn decoder() -> Props(Access) {
  use <- state.do(props.check_keys(access_keys))

  use users <- props.try("users", {
    zero.new(Users([]), decoder.from(users_decoder()))
  })

  use groups <- props.try("groups", {
    zero.list(decoder.from(decode.list(decode.string)))
  })

  use keys <- props.try("keys", {
    zero.list(decoder.from(decode.list(decode.string)))
  })

  state.succeed(Access(users:, groups:, keys:))
}

pub fn zero_decoder() -> Zero(Access) {
  use dynamic <- zero.new(none())
  use <- extra.return(props.decode(dynamic, _))
  use <- state.do(props.check_keys(access_keys))
  decoder()
}

fn users_decoder() -> Decoder(Users) {
  decode.string
  |> decode.then(user_decoder)
  |> decode.one_of([
    decode.list(decode.string) |> decode.map(Users),
  ])
}

fn user_decoder(string: String) -> Decoder(Users) {
  case string {
    "everyone" -> decode.success(Everyone)
    _string -> decode.failure(Everyone, "'everyone' or a list of users")
  }
}
