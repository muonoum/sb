import gleeunit/should
import sb/extra_server/path

pub fn relative_path_test() {
  path.relative(path: "/usr/local/lib/something", to: "/")
  |> should.be_ok
  |> should.equal("usr/local/lib/something")

  path.relative(path: "/usr/local/lib/something", to: "/usr/local")
  |> should.be_ok
  |> should.equal("lib/something")

  path.relative(path: "/usr/local/lib/something", to: "usr")
  |> should.be_ok
  |> should.equal("/usr/local/lib/something")

  path.relative(path: "/usr/local/lib/../something", to: "/usr/local")
  |> should.be_ok
  |> should.equal("something")

  path.relative(path: "/usr/local/lib/../../../something", to: "/usr/local")
  |> should.be_ok
  |> should.equal("/something")

  path.relative(path: "/usr/local/lib/../../../../something", to: "/usr/local")
  |> should.be_error

  //

  path.relative("/usr/local/foo", to: "/usr/local")
  |> should.be_ok
  |> should.equal("foo")

  path.relative("/usr/local/foo", to: "/")
  |> should.be_ok
  |> should.equal("usr/local/foo")

  path.relative("/usr/local/foo", to: "/etc")
  |> should.be_ok
  |> should.equal("/usr/local/foo")

  path.relative("/usr/local/foo", to: "/usr/local/foo")
  |> should.be_ok
  |> should.equal(".")

  path.relative("/usr/local/../foo", to: "/usr/foo")
  |> should.be_ok
  |> should.equal(".")

  path.relative("/usr/local/../foo/bar", to: "/usr/foo")
  |> should.be_ok
  |> should.equal("bar")

  path.relative("tmp/foo/bar", to: "tmp")
  |> should.be_ok
  |> should.equal("foo/bar")

  path.relative("tmp/foo/bar", to: "tmp/foo")
  |> should.be_ok
  |> should.equal("bar")

  path.relative("tmp/foo/bar", to: "tmp/bat")
  |> should.be_ok
  |> should.equal("tmp/foo/bar")

  path.relative(path: ".", to: "/usr/local")
  |> should.be_ok
  |> should.equal(".")

  path.relative(".", to: "/usr/local") |> should.be_ok |> should.equal(".")
  path.relative("foo", to: "/usr/local") |> should.be_ok |> should.equal("foo")

  path.relative("foo/../bar", to: "/usr/local")
  |> should.be_ok
  |> should.equal("bar")

  path.relative("foo/..", to: "/usr/local") |> should.be_ok |> should.equal(".")

  path.relative("../foo", to: "/usr/local")
  |> should.be_error
}
