import gleam/http
import wisp

// POST /api/form/form-id -- authorization, optional map from field ids to values --> form data or error
// PUT /api/form -- form data, map from fields id to values --> form data or error
// POST /api/job -- form data --> job id or error
// GET /api/job
// GET /api/job/follow

pub fn service(request: wisp.Request) -> wisp.Response {
  case request.method, wisp.path_segments(request) {
    http.Get, ["form", _id] -> todo
    http.Post, ["form", _id] -> todo
    http.Put, ["form"] -> todo
    http.Post, ["job"] -> todo
    http.Get, ["job"] -> todo
    http.Get, ["job", "follow"] -> todo

    _method, _segments -> wisp.not_found()
  }
}
