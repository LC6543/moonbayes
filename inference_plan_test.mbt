///|
test "inference plan reports bucket order and sizes" {
  let network = graph_chain_network()
  let plan = network.inference_plan(["c"], []).unwrap()
  assert_eq(plan.elimination_order(), ["a", "b"])
  assert_eq(plan.bucket_count(), 2)
  let first = plan.bucket(0).unwrap()
  assert_eq(first.variable(), "a")
  assert_eq(first.variables(), ["a", "b"])
  assert_eq(first.estimated_entries(), 4)
  let second = plan.bucket(1).unwrap()
  assert_eq(second.variable(), "b")
  assert_eq(second.variables(), ["c", "b"])
  assert_eq(second.estimated_entries(), 4)
  assert_eq(plan.max_bucket_size(), 4)
  assert_eq(plan.result_entries(), 2)
  match plan.bucket(-1) {
    None => ()
    Some(_) => assert_true(false)
  }
}

///|
test "inference plan accounts for evidence and validates inputs" {
  let network = rain_umbrella_network()
  let plan = network.inference_plan(["rain"], [("umbrella", 1)]).unwrap()
  assert_eq(plan.elimination_order(), [])
  assert_eq(plan.bucket_count(), 0)
  assert_eq(plan.result_entries(), 2)
  match network.inference_plan([], []) {
    Err(EmptyQuery) => ()
    _ => assert_true(false)
  }
  match network.inference_plan(["missing"], []) {
    Err(UnknownVariable("missing")) => ()
    _ => assert_true(false)
  }
}
