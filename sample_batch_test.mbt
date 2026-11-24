///|
test "prior sampling is deterministic and complete" {
  let network = rain_umbrella_network()
  let config = @moonbayes.SamplingConfig::new(2000, 20261125UL).unwrap()
  let first = network.sample_prior(config).unwrap()
  let second = network.sample_prior(config).unwrap()
  assert_eq(first.sample_count(), 2000)
  assert_eq(first.sample(0).unwrap(), second.sample(0).unwrap())
  assert_eq(first.sample(1999).unwrap(), second.sample(1999).unwrap())
  let row = first.sample(0).unwrap()
  assert_eq(row.length(), 2)
  assert_eq(row[0].0, "rain")
  assert_eq(row[1].0, "umbrella")
  assert_eq(first.sample(-1), None)
  assert_eq(first.sample(2000), None)
}

///|
test "prior sampling approximates marginal probabilities" {
  let network = rain_umbrella_network()
  let config = @moonbayes.SamplingConfig::new(20000, 42UL).unwrap()
  let batch = network.sample_prior(config).unwrap()
  let mut rain_true = 0
  let mut umbrella_true = 0
  let mut index = 0
  while index < batch.sample_count() {
    let row = batch.sample(index).unwrap()
    if row[0].1 == 1 {
      rain_true += 1
    }
    if row[1].1 == 1 {
      umbrella_true += 1
    }
    index += 1
  }
  let rain_frequency = rain_true.to_double() / batch.sample_count().to_double()
  let umbrella_frequency = umbrella_true.to_double() /
    batch.sample_count().to_double()
  assert_true((rain_frequency - 0.2).abs() < 0.02)
  assert_true((umbrella_frequency - 0.24).abs() < 0.02)
}
