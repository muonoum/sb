import extra
import extra/state
import gleam/dict
import gleam/dynamic/decode
import gleam/result
import sb/custom
import sb/decoder
import sb/error.{type Error}
import sb/props
import sb/report.{type Report}
import sb/value.{type Value}

const succeed_keys = ["kind"]

const parse_integer_keys = ["kind"]

const parse_float_keys = ["kind"]

const fail_keys = ["kind", "error-message"]

pub type Filter {
  Succeed
}

pub fn evaluate(value: Value, filter: Filter) -> Result(Value, Report(Error)) {
  case filter {
    Succeed -> Ok(value)
  }
}

pub fn decoder(filters: custom.Filters) {
  use name <- props.field("kind", decoder.new(decode.string))
  let context = report.context(_, error.BadKind(name))
  use <- extra.return(state.map_error(_, context))

  use <- result.lazy_unwrap({
    use custom <- result.map(dict.get(filters.custom, name))
    use <- state.do(state.update(dict.merge(_, custom)))
    decoder(filters)
  })

  case name {
    "succeed" -> {
      use <- state.do(props.check_unknown_keys(succeed_keys))
      props.succeed(Succeed)
    }

    _unknown -> todo as "unknown filter"
  }
}
