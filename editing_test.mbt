///|
test "replace distribution changes only the target node" {
  let network = rain_umbrella_network()
  let rain = @moonbayes.Variable::new("rain", 2).unwrap()
  let replacement = @moonbayes.Factor::new([rain], [0.1, 0.9]).unwrap()
  let edited = network.replace_distribution("rain", replacement).unwrap()
  assert_values(edited.distribution_of("rain").unwrap(), [0.1, 0.9])
  assert_values(network.distribution_of("rain").unwrap(), [0.8, 0.2])
  assert_values(edited.query(["rain"], []).unwrap(), [0.1, 0.9])
}

///|
test "replace distributions applies a validated batch" {
  let network = rain_umbrella_network()
  let rain = @moonbayes.Variable::new("rain", 2).unwrap()
  let umbrella = @moonbayes.Variable::new("umbrella", 2).unwrap()
  let rain_factor = @moonbayes.Factor::new([rain], [0.25, 0.75]).unwrap()
  let umbrella_factor = @moonbayes.Factor::new([umbrella, rain], [
    0.8, 0.3, 0.2, 0.7,
  ]).unwrap()
  let edited = network
    .replace_distributions([
      ("rain", rain_factor),
      ("umbrella", umbrella_factor),
    ])
    .unwrap()
  assert_values(edited.distribution_of("rain").unwrap(), [0.25, 0.75])
  assert_values(edited.distribution_of("umbrella").unwrap(), [
    0.8, 0.3, 0.2, 0.7,
  ])
}

///|
test "replace distributions rejects invalid edits" {
  let network = rain_umbrella_network()
  let rain = @moonbayes.Variable::new("rain", 2).unwrap()
  let factor = @moonbayes.Factor::new([rain], [0.5, 0.5]).unwrap()
  match network.replace_distributions([("rain", factor), ("rain", factor)]) {
    Err(DuplicateReplacement("rain")) => ()
    _ => assert_true(false)
  }
  match network.replace_distribution("missing", factor) {
    Err(UnknownNode("missing")) => ()
    _ => assert_true(false)
  }
  let umbrella = @moonbayes.Variable::new("umbrella", 2).unwrap()
  let bad_scope = @moonbayes.Factor::new([umbrella], [0.5, 0.5]).unwrap()
  match network.replace_distribution("rain", bad_scope) {
    Err(DistributionScopeMismatch("rain")) => ()
    _ => assert_true(false)
  }
}

///|
test "rename variable updates nodes parents and distributions" {
  let network = rain_umbrella_network()
  let renamed = network.rename_variable("rain", "weather").unwrap()
  assert_eq(renamed.topological_order(), ["weather", "umbrella"])
  match renamed.node("rain") {
    None => ()
    Some(_) => assert_true(false)
  }
  assert_eq(renamed.parents_of("umbrella").unwrap(), ["weather"])
  assert_eq(renamed.distribution_of("umbrella").unwrap().variable_names(), [
    "umbrella", "weather",
  ])
  assert_values(renamed.query(["weather"], [("umbrella", 1)]).unwrap(), [
    1.0 / 3.0,
    2.0 / 3.0,
  ])
}

///|
test "rename variable validates names" {
  let network = rain_umbrella_network()
  match network.rename_variable("missing", "weather") {
    Err(UnknownNode("missing")) => ()
    _ => assert_true(false)
  }
  match network.rename_variable("rain", "umbrella") {
    Err(DuplicateNode("umbrella")) => ()
    _ => assert_true(false)
  }
  match network.rename_variable("rain", "") {
    Err(FactorFailure(EmptyVariableName)) => ()
    _ => assert_true(false)
  }
}
