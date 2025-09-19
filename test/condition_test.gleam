import gleeunit/should
import sb/forms/condition
import sb/forms/scope
import sb/forms/value

pub fn condition_test() {
  // scope={} | a==10
  condition.Equal("a", value.Int(10))
  |> condition.evaluate(scope.error())
  |> should.equal(condition.Equal("a", value.Int(10)))

  // scope={a=10} | a==20
  condition.Equal("a", value.Int(20))
  |> condition.evaluate(scope.put(scope.error(), "a", Ok(value.Int(10))))
  |> should.equal(condition.Resolved(False))

  // scope={} | a!=10
  condition.NotEqual("a", value.Int(10))
  |> condition.evaluate(scope.error())
  |> should.equal(condition.NotEqual("a", value.Int(10)))

  // scope={a=10} | a!=20
  condition.Equal("a", value.Int(20))
  |> condition.evaluate(scope.put(scope.error(), "a", Ok(value.Int(10))))
  |> should.equal(condition.Resolved(False))
}
