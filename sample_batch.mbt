///|
/// A deterministic batch of complete joint samples from a Bayesian network.
pub struct SampleBatch {
  priv rows : Array[Array[(String, Int32)]]
}

///|
/// Returns the number of complete assignments in this batch.
pub fn SampleBatch::sample_count(self : SampleBatch) -> Int32 {
  self.rows.length()
}

///|
/// Returns one complete assignment in topological variable order.
pub fn SampleBatch::sample(
  self : SampleBatch,
  index : Int32,
) -> Array[(String, Int32)]? {
  if index < 0 || index >= self.rows.length() {
    None
  } else {
    Some(self.rows[index].copy())
  }
}

///|
/// Draws complete joint assignments in topological order.
///
/// The same configuration seed always produces the same sample batch.
pub fn BayesianNetwork::sample_prior(
  self : BayesianNetwork,
  config : SamplingConfig,
) -> Result[SampleBatch, SamplingFailure] {
  let rng = @random.Rand::chacha8(seed=seed_bytes(config.seed()))
  let rows : Array[Array[(String, Int32)]] = []
  let mut sample_index = 0
  while sample_index < config.samples() {
    let assignment = Array::make(self.order.length(), 0)
    let row : Array[(String, Int32)] = []
    let mut position = 0
    while position < self.order.length() {
      let name = self.order[position]
      let node = match find_network_node(self.nodes, name) {
        Some(node) => node
        None => return Err(UnknownVariable(name))
      }
      let value = match sample_node_value(node, assignment, self.order, rng) {
        Value(value) => value
        Failure(error) => return Err(error)
      }
      assignment[position] = value
      row.push((name, value))
      position += 1
    }
    rows.push(row)
    sample_index += 1
  }
  Ok(SampleBatch::{ rows, })
}
