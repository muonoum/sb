pub fn map(pair: #(a, b), mapper: fn(a, b) -> c) -> c {
  let #(a, b) = pair
  mapper(a, b)
}
