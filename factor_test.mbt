///|
fn close_enough(left : Double, right : Double) -> Bool {
  (left - right).abs() < 1.0e-12
}

///|
fn assert_values(
  factor : @moonbayes.Factor,
  expected : Array[Double],
) -> Unit raise {
  let actual = factor.values()
  assert_eq(actual.length(), expected.length())
  let mut index = 0
  while index < expected.length() {
    assert_true(close_enough(actual[index], expected[index]))
    index += 1
  }
}

///|
test "variable validation" {
  let valid = @moonbayes.Variable::new("rain", 2).unwrap()
  assert_eq(valid.name(), "rain")
  assert_eq(valid.size(), 2)
  match @moonbayes.Variable::new("", 2) {
    Err(EmptyVariableName) => ()
    _ => assert_true(false)
  }
  match @moonbayes.Variable::new("bad", 0) {
    Err(InvalidDomainSize(0)) => ()
    _ => assert_true(false)
  }
}

///|
test "factor uses last-variable-fastest layout" {
  let rain = @moonbayes.Variable::new("rain", 2).unwrap()
  let umbrella = @moonbayes.Variable::new("umbrella", 2).unwrap()
  let factor = @moonbayes.Factor::new([rain, umbrella], [0.8, 0.2, 0.1, 0.9]).unwrap()
  assert_eq(factor.variable_count(), 2)
  assert_eq(factor.value_count(), 4)
  assert_eq(factor.variable_names(), ["rain", "umbrella"])
  assert_eq(factor.index_of([0, 0]).unwrap(), 0)
  assert_eq(factor.index_of([0, 1]).unwrap(), 1)
  assert_eq(factor.index_of([1, 0]).unwrap(), 2)
  assert_eq(factor.index_of([1, 1]).unwrap(), 3)
  assert_eq(factor.assignment_at(2).unwrap(), [1, 0])
  assert_true(close_enough(factor.value_at([1, 1]).unwrap(), 0.9))
}

///|
test "factor validates shape and entries" {
  let rain = @moonbayes.Variable::new("rain", 2).unwrap()
  match @moonbayes.Factor::new([rain], [0.4]) {
    Err(ValueCountMismatch(2, 1)) => ()
    _ => assert_true(false)
  }
  let finite = @moonbayes.Variable::new("finite", 2).unwrap()
  match @moonbayes.Factor::new([finite], [0.0, @double.infinity]) {
    Err(NonFiniteValue(1)) => ()
    _ => assert_true(false)
  }
  let non_negative = @moonbayes.Variable::new("weight", 2).unwrap()
  match @moonbayes.Factor::new([non_negative], [1.0, -0.5]) {
    Err(NegativeValue(1)) => ()
    _ => assert_true(false)
  }
}

///|
test "factor rejects duplicate variable names" {
  let first = @moonbayes.Variable::new("x", 2).unwrap()
  let second = @moonbayes.Variable::new("x", 3).unwrap()
  match
    @moonbayes.Factor::new([first, second], [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]) {
    Err(DuplicateVariable("x")) => ()
    _ => assert_true(false)
  }
}

///|
test "normalize produces a probability table" {
  let x = @moonbayes.Variable::new("x", 2).unwrap()
  let factor = @moonbayes.Factor::new([x], [1.0, 3.0]).unwrap()
  let normalized = factor.normalize().unwrap()
  assert_values(normalized, [0.25, 0.75])
  assert_true(close_enough(normalized.total(), 1.0))
}

///|
test "normalize rejects zero mass" {
  let x = @moonbayes.Variable::new("x", 2).unwrap()
  let factor = @moonbayes.Factor::new([x], [0.0, 0.0]).unwrap()
  match factor.normalize() {
    Err(ZeroMass) => ()
    _ => assert_true(false)
  }
}

///|
test "multiply combines shared and disjoint scopes" {
  let rain = @moonbayes.Variable::new("rain", 2).unwrap()
  let umbrella = @moonbayes.Variable::new("umbrella", 2).unwrap()
  let prior = @moonbayes.Factor::new([rain], [0.8, 0.2]).unwrap()
  let conditional = @moonbayes.Factor::new([rain, umbrella], [
    0.9, 0.1, 0.2, 0.8,
  ]).unwrap()
  let joint = prior.multiply(conditional).unwrap()
  assert_eq(joint.variable_names(), ["rain", "umbrella"])
  assert_values(joint, [0.72, 0.08, 0.04, 0.16])
  assert_true(close_enough(joint.total(), 1.0))
}

///|
test "multiply rejects incompatible shared domains" {
  let left = @moonbayes.Factor::new(
    [@moonbayes.Variable::new("x", 2).unwrap()],
    [0.5, 0.5],
  ).unwrap()
  let right = @moonbayes.Factor::new(
    [@moonbayes.Variable::new("x", 3).unwrap()],
    [0.2, 0.3, 0.5],
  ).unwrap()
  match left.multiply(right) {
    Err(IncompatibleVariable("x", 2, 3)) => ()
    _ => assert_true(false)
  }
}

///|
test "multiply supports disjoint scopes" {
  let left = @moonbayes.Factor::new(
    [@moonbayes.Variable::new("a", 2).unwrap()],
    [0.2, 0.8],
  ).unwrap()
  let right = @moonbayes.Factor::new(
    [@moonbayes.Variable::new("b", 3).unwrap()],
    [0.1, 0.3, 0.6],
  ).unwrap()
  let product = left.multiply(right).unwrap()
  assert_eq(product.variable_names(), ["a", "b"])
  assert_values(product, [0.02, 0.06, 0.12, 0.08, 0.24, 0.48])
}

///|
test "marginalize removes selected variables" {
  let rain = @moonbayes.Variable::new("rain", 2).unwrap()
  let umbrella = @moonbayes.Variable::new("umbrella", 2).unwrap()
  let joint = @moonbayes.Factor::new([rain, umbrella], [0.72, 0.08, 0.04, 0.16]).unwrap()
  let umbrella_only = joint.marginalize(["umbrella"]).unwrap()
  assert_eq(umbrella_only.variable_names(), ["umbrella"])
  assert_values(umbrella_only, [0.76, 0.24])
  let rain_only = joint.marginalize(["rain"]).unwrap()
  assert_eq(rain_only.variable_names(), ["rain"])
  assert_values(rain_only, [0.8, 0.2])
}

///|
test "marginalize supports scalar factors" {
  let x = @moonbayes.Variable::new("x", 3).unwrap()
  let factor = @moonbayes.Factor::new([x], [0.2, 0.3, 0.5]).unwrap()
  let scalar = factor.marginalize([]).unwrap()
  assert_eq(scalar.variable_count(), 0)
  assert_values(scalar, [1.0])
}

///|
test "marginalize validates retained names" {
  let x = @moonbayes.Variable::new("x", 2).unwrap()
  let factor = @moonbayes.Factor::new([x], [0.5, 0.5]).unwrap()
  match factor.marginalize(["missing"]) {
    Err(UnknownVariable("missing")) => ()
    _ => assert_true(false)
  }
  match factor.marginalize(["x", "x"]) {
    Err(DuplicateVariable("x")) => ()
    _ => assert_true(false)
  }
}

///|
test "assignment validation reports the offending position" {
  let x = @moonbayes.Variable::new("x", 2).unwrap()
  let y = @moonbayes.Variable::new("y", 3).unwrap()
  let factor = @moonbayes.Factor::new([x, y], [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]).unwrap()
  match factor.index_of([0]) {
    Err(AssignmentLengthMismatch(2, 1)) => ()
    _ => assert_true(false)
  }
  match factor.index_of([0, 3]) {
    Err(AssignmentOutOfRange(1, 3, 3)) => ()
    _ => assert_true(false)
  }
}

///|
test "assignment lookup rejects an invalid table index" {
  let x = @moonbayes.Variable::new("x", 2).unwrap()
  let factor = @moonbayes.Factor::new([x], [0.4, 0.6]).unwrap()
  match factor.assignment_at(2) {
    Err(IndexOutOfBounds(2, 2)) => ()
    _ => assert_true(false)
  }
}
