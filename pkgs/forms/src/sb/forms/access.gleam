import gleam/dynamic/decode.{type Decoder}
import sb/extra/function.{return}
import sb/extra/state
import sb/forms/decoder
import sb/forms/props
import sb/forms/zero.{type Zero}

const access_keys = ["users", "groups", "keys"]

pub type Access {
  Access(users: Users, groups: List(String), keys: List(String))
}

pub type Users {
  Everyone
  Users(List(String))
}

pub type Key {
  Key(id: String, secret: String)
}

pub fn everyone() -> Access {
  Access(users: Everyone, groups: [], keys: [])
}

pub fn none() -> Access {
  Access(users: Users([]), groups: [], keys: [])
}

pub fn decoder(default: Access) -> Zero(Access, Nil) {
  use dynamic <- zero.new(default)
  use <- return(props.decode(dynamic, _))
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

  state.ok(Access(users:, groups:, keys:))
}

fn users_decoder() -> Decoder(Users) {
  decode.string
  |> decode.then(user_decoder)
  |> decode.one_of([
    decode.map(decode.list(decode.string), Users),
  ])
}

fn user_decoder(string: String) -> Decoder(Users) {
  case string {
    "everyone" -> decode.success(Everyone)
    _string -> decode.failure(Everyone, "'everyone' or a list of users")
  }
}
