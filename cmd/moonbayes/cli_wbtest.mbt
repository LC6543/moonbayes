///|
test "parse targets and evidence options" {
  let options = parse_options(
    ["--target", "rain", "--target", "umbrella", "--evidence", "umbrella=1"],
    0,
  )
  assert_eq(options.targets, ["rain", "umbrella"])
  assert_eq(options.evidence, [("umbrella", 1)])
}

///|
test "parse evidence rejects malformed input" {
  let parsed : (String, Int32)? = Some(parse_evidence("rain")) catch {
    _ => None
  }
  assert_true(parsed is None)
}
