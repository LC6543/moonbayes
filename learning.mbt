///|
/// Errors produced while fitting model parameters from complete observations.
pub enum FitFailure {
  EmptyData
  InvalidSmoothing(Double)
  UnknownVariable(String)
  DuplicateObservation(String)
  MissingObservation(String)
  ObservationOutOfRange(String, Int32, Int32)
  UnobservedParentConfiguration(String)
  FactorFailure(FactorError)
  NetworkFailure(NetworkError)
}

///|
/// Returns a human-readable explanation of a fitting error.
pub fn FitFailure::message(self : FitFailure) -> String {
  match self {
    EmptyData => "at least one complete observation is required"
    InvalidSmoothing(value) =>
      "smoothing must be finite and non-negative, got " + value.to_string()
    UnknownVariable(name) => "observation contains an unknown variable: " + name
    DuplicateObservation(name) => "observation repeats variable: " + name
    MissingObservation(name) => "observation is missing variable: " + name
    ObservationOutOfRange(name, value, size) =>
      "observation value " +
      value.to_string() +
      " for " +
      name +
      " is outside domain size " +
      size.to_string()
    UnobservedParentConfiguration(name) =>
      "no observations cover a parent configuration for node: " + name
    FactorFailure(error) => error.message()
    NetworkFailure(error) => error.message()
  }
}

///|
/// Fits conditional probability tables from complete joint observations.
///
/// The graph structure and variable domains are preserved. `smoothing` is
/// added to every child count before normalization. A zero smoothing value is
/// allowed only when every parent configuration is observed.
pub fn BayesianNetwork::fit_complete_data(
  self : BayesianNetwork,
  data : Array[Array[(String, Int32)]],
  smoothing : Double,
) -> Result[BayesianNetwork, FitFailure] {
  if data.length() == 0 {
    return Err(EmptyData)
  }
  if smoothing < 0.0 || smoothing.is_nan() || smoothing.is_inf() {
    return Err(InvalidSmoothing(smoothing))
  }
  let normalized_rows : Array[Array[Int32]] = []
  for row in data {
    let values = Array::make(self.order.length(), -1)
    for entry in row {
      let (name, value) = entry
      let position = find_name_position(self.order, name)
      if position < 0 {
        return Err(UnknownVariable(name))
      }
      if values[position] >= 0 {
        return Err(DuplicateObservation(name))
      }
      let node = match find_network_node(self.nodes, name) {
        Some(node) => node
        None => return Err(UnknownVariable(name))
      }
      let size = node.variable().size()
      if value < 0 || value >= size {
        return Err(ObservationOutOfRange(name, value, size))
      }
      values[position] = value
    }
    let mut position = 0
    while position < values.length() {
      if values[position] < 0 {
        return Err(MissingObservation(self.order[position]))
      }
      position += 1
    }
    normalized_rows.push(values)
  }
  let fitted_nodes : Array[NetworkNode] = []
  for node in self.nodes {
    let scope = node.distribution().scope()
    let count_size = match factor_table_size(scope) {
      Ok(size) => size
      Err(error) => return Err(FactorFailure(error))
    }
    let counts = Array::make(count_size, smoothing)
    for row in normalized_rows {
      let assignment = Array::make(scope.length(), 0)
      let mut position = 0
      while position < scope.length() {
        let source = find_name_position(self.order, scope[position].name())
        assignment[position] = row[source]
        position += 1
      }
      counts[assignment_to_index(scope, assignment)] += 1.0
    }
    let parent_variables : Array[Variable] = []
    let mut position = 1
    while position < scope.length() {
      parent_variables.push(scope[position])
      position += 1
    }
    let parent_count = match factor_table_size(parent_variables) {
      Ok(count) => count
      Err(error) => return Err(FactorFailure(error))
    }
    let probabilities = Array::make(count_size, 0.0)
    let child_size = scope[0].size()
    let mut parent_index = 0
    while parent_index < parent_count {
      let parent_assignment = index_to_assignment(
        parent_variables, parent_index,
      )
      let assignment = Array::make(scope.length(), 0)
      position = 1
      while position < scope.length() {
        assignment[position] = parent_assignment[position - 1]
        position += 1
      }
      let mut total = 0.0
      let mut child_value = 0
      while child_value < child_size {
        assignment[0] = child_value
        total += counts[assignment_to_index(scope, assignment)]
        child_value += 1
      }
      if total == 0.0 {
        return Err(UnobservedParentConfiguration(node.variable_name()))
      }
      child_value = 0
      while child_value < child_size {
        assignment[0] = child_value
        let index = assignment_to_index(scope, assignment)
        probabilities[index] = counts[index] / total
        child_value += 1
      }
      parent_index += 1
    }
    let distribution = match Factor::new(scope, probabilities) {
      Ok(factor) => factor
      Err(error) => return Err(FactorFailure(error))
    }
    let fitted = match
      NetworkNode::new(node.variable(), node.parents(), distribution) {
      Ok(node) => node
      Err(error) => return Err(NetworkFailure(error))
    }
    fitted_nodes.push(fitted)
  }
  match BayesianNetwork::new(fitted_nodes) {
    Ok(network) => Ok(network)
    Err(error) => Err(NetworkFailure(error))
  }
}
