import wisp

pub fn service(_request: wisp.Request, _segments: List(String)) -> wisp.Response {
  wisp.not_found()
}
