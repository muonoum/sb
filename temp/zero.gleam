// props

pub fn decode(dynamic: Dynamic, decoder: Props(v)) -> Result(v, Report(Error)) {
  let context = Context(dict: dict.new(), reports: [])

  state.run(context:, state: {
    use <- load(dynamic)
    use value <- state.with(decoder)
    use reports <- get_reports

    case reports {
      [] -> state.succeed(value)
      reports -> state.fail(report.new(error.Collected(list.reverse(reports))))
    }
  })
}

fn property(
  name: String,
  decoder: fn(Dynamic) -> Zero(v),
  zero: fn(v) -> Zero(v),
) -> Props(v) {
  use dict <- get

  let result = case dict.get(dict, name) {
    Error(Nil) -> zero(pair.first(decoder(dynamic.nil())))

    Ok(dynamic) -> {
      use report <- pair.map_second(decoder(dynamic))
      option.map(report, report.context(_, error.BadProperty(name)))
    }
  }

  case result {
    #(value, None) -> state.succeed(value)

    #(_value, Some(report)) -> {
      use <- state.do(add_report(report))
      state.succeed(value)
    }
  }
}

pub fn required(
  name: String,
  decoder: fn(Dynamic) -> Zero(a),
  then: fn(a) -> Props(b),
) -> Props(b) {
  state.with(then:, with: {
    use zero <- property(name, decoder)
    #(zero, Some(report.new(error.MissingProperty(name))))
  })
}

pub fn zero(
  name: String,
  decoder: fn(Dynamic) -> Zero(a),
  then: fn(a) -> Props(b),
) -> Props(b) {
  state.with(then:, with: {
    use zero <- property(name, decoder)
    #(zero, None)
  })
}

pub fn default(
  name: String,
  default: Result(a, Report(Error)),
  decoder: fn(Dynamic) -> Zero(a),
  then: fn(a) -> Props(b),
) -> Props(b) {
  state.with(then:, with: {
    use zero <- property(name, decoder)

    case default {
      Error(report) -> #(zero, Some(report))
      Ok(value) -> #(value, None)
    }
  })
}

// zero

pub type Zero(v) =
  #(v, Option(Report(Error)))

pub fn new(
  zero: v,
  decoder: Decoder(v),
) -> fn(Dynamic) -> #(v, Option(Report(Error))) {
  fn(dynamic) {
    case decoder(dynamic) {
      Error(report) -> #(zero, Some(report))
      Ok(value) -> #(value, None)
    }
  }
}

pub fn string(decoder: decoder.Decoder(String)) -> fn(Dynamic) -> Zero(String) {
  new("", decoder)
}

pub fn bool(decoder: Decoder(Bool)) -> fn(Dynamic) -> Zero(Bool) {
  new(False, decoder)
}

pub fn list(decoder: Decoder(List(v))) -> fn(Dynamic) -> Zero(List(v)) {
  new([], decoder)
}

pub fn option(decoder: Decoder(Option(v))) -> fn(Dynamic) -> Zero(Option(v)) {
  new(None, decoder)
}
