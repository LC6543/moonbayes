///|
fn assert_sampling_values(
  result : @moonbayes.WeightedPosterior,
  expected : Array[Double],
  tolerance : Double,
) -> Unit raise {
  let actual = result.estimate().values()
  assert_eq(actual.length(), expected.length())
  let mut index = 0
  while index < expected.length() {
    assert_true((actual[index] - expected[index]).abs() < tolerance)
    index += 1
  }
}

///|
test "sampling config validates sample counts" {
  match @moonbayes.SamplingConfig::new(0, 1UL) {
    Err(InvalidSampleCount(0)) => ()
    _ => assert_true(false)
  }
  match @moonbayes.SamplingConfig::new(@moonbayes.MAX_SAMPLES + 1, 1UL) {
    Err(SampleCountTooLarge(count)) =>
      assert_eq(count, @moonbayes.MAX_SAMPLES + 1)
    _ => assert_true(false)
  }
  let config = @moonbayes.SamplingConfig::new(100, 42UL).unwrap()
  assert_eq(config.samples(), 100)
  assert_eq(config.seed(), 42UL)
}

///|
test "likelihood weighting estimates posterior probabilities" {
  let network = rain_umbrella_network()
  let config = @moonbayes.SamplingConfig::new(20000, 20261125UL).unwrap()
  let rain_given_umbrella = network
    .sample_posterior(["rain"], [("umbrella", 1)], config)
    .unwrap()
  assert_sampling_values(rain_given_umbrella, [1.0 / 3.0, 2.0 / 3.0], 0.02)
  assert_true(rain_given_umbrella.effective_sample_size() > 5000.0)
  assert_true(rain_given_umbrella.effective_sample_size() <= 20000.0)
}

///|
test "likelihood weighting is deterministic for the same seed" {
  let network = rain_umbrella_network()
  let config = @moonbayes.SamplingConfig::new(2000, 7UL).unwrap()
  let first = network.sample_posterior(["umbrella"], [], config).unwrap()
  let second = network.sample_posterior(["umbrella"], [], config).unwrap()
  assert_eq(first.estimate().values(), second.estimate().values())
  assert_eq(first.effective_sample_size(), second.effective_sample_size())
}

///|
test "likelihood weighting rejects zero-weight evidence" {
  let x = @moonbayes.Variable::new("x", 2).unwrap()
  let y = @moonbayes.Variable::new("y", 2).unwrap()
  let x_factor = @moonbayes.Factor::new([x], [1.0, 0.0]).unwrap()
  let y_factor = @moonbayes.Factor::new([y, x], [0.5, 0.5, 0.5, 0.5]).unwrap()
  let x_node = @moonbayes.NetworkNode::new(x, [], x_factor).unwrap()
  let y_node = @moonbayes.NetworkNode::new(y, ["x"], y_factor).unwrap()
  let network = @moonbayes.BayesianNetwork::new([x_node, y_node]).unwrap()
  let config = @moonbayes.SamplingConfig::new(100, 1UL).unwrap()
  match network.sample_posterior(["y"], [("x", 1)], config) {
    Err(ZeroWeight) => ()
    _ => assert_true(false)
  }
}

///|
test "likelihood weighting validates targets and evidence" {
  let network = rain_umbrella_network()
  let config = @moonbayes.SamplingConfig::new(100, 1UL).unwrap()
  match network.sample_posterior([], [], config) {
    Err(EmptyTargets) => ()
    _ => assert_true(false)
  }
  match network.sample_posterior(["missing"], [], config) {
    Err(UnknownVariable("missing")) => ()
    _ => assert_true(false)
  }
  match network.sample_posterior(["rain", "rain"], [], config) {
    Err(DuplicateTarget("rain")) => ()
    _ => assert_true(false)
  }
  match network.sample_posterior(["rain"], [("rain", 0)], config) {
    Err(TargetIsEvidence("rain")) => ()
    _ => assert_true(false)
  }
  match
    network.sample_posterior(
      ["rain"],
      [("umbrella", 0), ("umbrella", 1)],
      config,
    ) {
    Err(DuplicateEvidence("umbrella")) => ()
    _ => assert_true(false)
  }
  match network.sample_posterior(["rain"], [("umbrella", 2)], config) {
    Err(EvidenceOutOfRange("umbrella", 2, 2)) => ()
    _ => assert_true(false)
  }
}
