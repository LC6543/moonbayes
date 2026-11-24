///|
fn fitting_data() -> Array[Array[(String, Int32)]] {
  [
    [("rain", 0), ("umbrella", 0)],
    [("umbrella", 0), ("rain", 0)],
    [("rain", 0), ("umbrella", 1)],
    [("rain", 1), ("umbrella", 1)],
  ]
}

///|
test "complete data fitting learns smoothed CPTs" {
  let network = rain_umbrella_network()
  let fitted = network.fit_complete_data(fitting_data(), 1.0).unwrap()
  let rain = fitted.distribution_of("rain").unwrap()
  assert_values(rain, [4.0 / 6.0, 2.0 / 6.0])
  let umbrella = fitted.distribution_of("umbrella").unwrap()
  assert_eq(umbrella.variable_names(), ["umbrella", "rain"])
  assert_values(umbrella, [0.6, 1.0 / 3.0, 0.4, 2.0 / 3.0])
}

///|
test "complete data fitting supports zero smoothing" {
  let network = rain_umbrella_network()
  let data = [[("rain", 0), ("umbrella", 0)], [("rain", 1), ("umbrella", 1)]]
  let fitted = network.fit_complete_data(data, 0.0).unwrap()
  assert_values(fitted.distribution_of("rain").unwrap(), [0.5, 0.5])
  assert_values(fitted.distribution_of("umbrella").unwrap(), [
    1.0, 0.0, 0.0, 1.0,
  ])
}

///|
test "complete data fitting validates observations" {
  let network = rain_umbrella_network()
  match network.fit_complete_data([], 1.0) {
    Err(EmptyData) => ()
    _ => assert_true(false)
  }
  match network.fit_complete_data(fitting_data(), -1.0) {
    Err(InvalidSmoothing(-1.0)) => ()
    _ => assert_true(false)
  }
  match network.fit_complete_data([[("rain", 0), ("missing", 0)]], 1.0) {
    Err(UnknownVariable("missing")) => ()
    _ => assert_true(false)
  }
  match
    network.fit_complete_data(
      [[("rain", 0), ("rain", 1), ("umbrella", 0)]],
      1.0,
    ) {
    Err(DuplicateObservation("rain")) => ()
    _ => assert_true(false)
  }
  match network.fit_complete_data([[("rain", 0)]], 1.0) {
    Err(MissingObservation("umbrella")) => ()
    _ => assert_true(false)
  }
  match network.fit_complete_data([[("rain", 2), ("umbrella", 0)]], 1.0) {
    Err(ObservationOutOfRange("rain", 2, 2)) => ()
    _ => assert_true(false)
  }
}

///|
test "zero smoothing rejects unobserved parent configurations" {
  let network = rain_umbrella_network()
  let data = [[("rain", 0), ("umbrella", 0)], [("rain", 0), ("umbrella", 1)]]
  match network.fit_complete_data(data, 0.0) {
    Err(UnobservedParentConfiguration("umbrella")) => ()
    _ => assert_true(false)
  }
}
