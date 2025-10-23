import gleam/list

pub opaque type Zipper(v) {
  Zipper(before: List(v), focus: v, after: List(v))
}

pub fn focus(zip: Zipper(v)) {
  zip.focus
}

pub fn new(focus: v, after: List(v)) -> Zipper(v) {
  Zipper(before: [], focus: focus, after: after)
}

pub fn to_list(zip: Zipper(v)) -> List(v) {
  list.append(list.reverse(zip.before), [zip.focus, ..zip.after])
}

pub fn map(zip: Zipper(v), with: fn(v) -> v) -> Zipper(v) {
  let Zipper(before, focus, after) = zip
  Zipper(list.map(before, with), with(focus), list.map(after, with))
}

pub fn next(zip: Zipper(v)) -> Result(Zipper(v), Nil) {
  case zip.after {
    [] -> Error(Nil)

    [next, ..after] -> {
      let before = [zip.focus, ..zip.before]
      Ok(Zipper(before: before, focus: next, after: after))
    }
  }
}

pub fn previous(zip: Zipper(v)) -> Result(Zipper(v), Nil) {
  case zip.before {
    [] -> Error(Nil)

    [previous, ..before] -> {
      let after = [zip.focus, ..zip.after]
      Ok(Zipper(before: before, focus: previous, after: after))
    }
  }
}
