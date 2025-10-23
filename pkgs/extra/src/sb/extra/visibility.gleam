pub type Visibility {
  Visible
  Hidden
}

pub fn toggle(v: Visibility) -> Visibility {
  case v {
    Hidden -> Visible
    Visible -> Hidden
  }
}
