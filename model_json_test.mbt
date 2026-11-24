///|
test "json round trip preserves network behavior" {
  let network = chain_network()
  let text = network.to_json_string()
  let restored = @moonbayes.BayesianNetwork::from_json_string(text).unwrap()
  assert_eq(restored.topological_order(), network.topological_order())
  assert_eq(restored.node_count(), network.node_count())
  let before = network.query(["a"], [("c", 0)]).unwrap()
  let after = restored.query(["a"], [("c", 0)]).unwrap()
  assert_eq(before.variable_names(), after.variable_names())
  assert_eq(before.values(), after.values())
  assert_eq(restored.to_json(), network.to_json())
}

///|
test "json rejects malformed and unsupported documents" {
  match @moonbayes.BayesianNetwork::from_json_string("{") {
    Err(InvalidJson(_)) => ()
    _ => assert_true(false)
  }
  let wrong_format = @json.parse(
    "{\"format\":\"other\",\"version\":1,\"nodes\":[]}",
  )
  match @moonbayes.BayesianNetwork::from_json(wrong_format) {
    Err(InvalidModelFormat) => ()
    _ => assert_true(false)
  }
  let wrong_version = @json.parse(
    "{\"format\":\"moonbayes\",\"version\":2,\"nodes\":[]}",
  )
  match @moonbayes.BayesianNetwork::from_json(wrong_version) {
    Err(UnsupportedFormatVersion(2)) => ()
    _ => assert_true(false)
  }
  let missing_nodes = @json.parse("{\"format\":\"moonbayes\",\"version\":1}")
  match @moonbayes.BayesianNetwork::from_json(missing_nodes) {
    Err(InvalidField("nodes")) => ()
    _ => assert_true(false)
  }
}

///|
test "json validates imported factors and network structure" {
  let bad_factor = @json.parse(
    "{\"format\":\"moonbayes\",\"version\":1,\"nodes\":[{\"variable\":{\"name\":\"x\",\"domain\":2},\"parents\":[],\"distribution\":{\"variables\":[{\"name\":\"x\",\"domain\":2}],\"values\":[0.5]}}]}",
  )
  match @moonbayes.BayesianNetwork::from_json(bad_factor) {
    Err(FactorFailure(ValueCountMismatch(2, 1))) => ()
    _ => assert_true(false)
  }
  let cyclic = @json.parse(
    "{\"format\":\"moonbayes\",\"version\":1,\"nodes\":[{\"variable\":{\"name\":\"a\",\"domain\":2},\"parents\":[\"b\"],\"distribution\":{\"variables\":[{\"name\":\"a\",\"domain\":2},{\"name\":\"b\",\"domain\":2}],\"values\":[0.5,0.5,0.5,0.5]}},{\"variable\":{\"name\":\"b\",\"domain\":2},\"parents\":[\"a\"],\"distribution\":{\"variables\":[{\"name\":\"b\",\"domain\":2},{\"name\":\"a\",\"domain\":2}],\"values\":[0.5,0.5,0.5,0.5]}}]}",
  )
  match @moonbayes.BayesianNetwork::from_json(cyclic) {
    Err(CycleDetected) => ()
    _ => assert_true(false)
  }
}
