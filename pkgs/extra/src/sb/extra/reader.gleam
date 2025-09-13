pub type Reader(e, a) {
  Reader(run: fn(e) -> a)
}

pub fn return(a: a) -> Reader(e, a) {
  use _ <- Reader
  a
}

pub fn do(reader: Reader(e, a), then: fn(a) -> Reader(e, b)) -> Reader(e, b) {
  use v <- Reader
  let a = reader.run(v)
  let b = then(a)
  b.run(v)
}

pub fn ask(e: e) -> e {
  e
}

pub fn main() {
  let r =
    Reader({
      use x <- ask
      echo x
      use x <- ask
      echo x
      return(99)
    })

  r.run(10)
  |> echo
}
