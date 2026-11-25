///|
/// Errors produced while constructing a discrete Bayesian network.
pub enum NetworkError {
  EmptyNetwork
  DuplicateNode(String)
  UnknownNode(String)
  UnknownParent(String)
  DuplicateParent(String)
  SelfParent(String)
  DistributionScopeMismatch(String)
  DistributionChildDomainMismatch(String, Int32, Int32)
  DistributionParentDomainMismatch(String, String, Int32, Int32)
  UnnormalizedConditional(String, Double)
  CycleDetected
  InvalidJson(String)
  InvalidModelFormat
  UnsupportedFormatVersion(Int32)
  InvalidField(String)
  FactorFailure(FactorError)
  DuplicateReplacement(String)
}

///|
/// Returns a human-readable explanation of a network error.
pub fn NetworkError::message(self : NetworkError) -> String {
  match self {
    EmptyNetwork => "a Bayesian network must contain at least one node"
    DuplicateNode(name) => "node appears more than once: " + name
    UnknownNode(name) => "node does not exist: " + name
    UnknownParent(name) => "parent node does not exist: " + name
    DuplicateParent(name) => "parent appears more than once: " + name
    SelfParent(name) => "node cannot be its own parent: " + name
    DistributionScopeMismatch(name) =>
      "distribution scope must be the child followed by its parents: " + name
    DistributionChildDomainMismatch(name, expected, actual) =>
      "distribution child domain for " +
      name +
      " must be " +
      expected.to_string() +
      ", got " +
      actual.to_string()
    DistributionParentDomainMismatch(name, parent, expected, actual) =>
      "distribution domain for parent " +
      parent +
      " of " +
      name +
      " must be " +
      expected.to_string() +
      ", got " +
      actual.to_string()
    UnnormalizedConditional(name, mass) =>
      "conditional distribution for " +
      name +
      " has mass " +
      mass.to_string() +
      " for one parent assignment"
    CycleDetected => "Bayesian network contains a directed cycle"
    InvalidJson(message) => "invalid JSON: " + message
    InvalidModelFormat => "JSON document is not a moonbayes model"
    UnsupportedFormatVersion(version) =>
      "unsupported moonbayes format version: " + version.to_string()
    InvalidField(path) => "invalid or missing model field: " + path
    FactorFailure(error) => error.message()
    DuplicateReplacement(name) =>
      "distribution replacement appears more than once: " + name
  }
}

///|
/// A variable together with its parent names and local conditional table.
pub struct NetworkNode {
  priv variable : Variable
  priv parents : Array[String]
  priv distribution : Factor
}

///|
/// Creates a node from a child variable, ordered parent names and local table.
///
/// The distribution scope must be the child followed by the parents in the
/// same order. For every parent assignment, the child values must sum to one.
pub fn NetworkNode::new(
  variable : Variable,
  parents : Array[String],
  distribution : Factor,
) -> Result[NetworkNode, NetworkError] {
  let mut parent_index = 0
  while parent_index < parents.length() {
    let parent = parents[parent_index]
    if parent == variable.name() {
      return Err(SelfParent(parent))
    }
    let mut previous = 0
    while previous < parent_index {
      if parents[previous] == parent {
        return Err(DuplicateParent(parent))
      }
      previous += 1
    }
    parent_index += 1
  }
  let scope = distribution.scope()
  let expected_variable_count = parents.length() + 1
  if scope.length() != expected_variable_count ||
    scope[0].name() != variable.name() {
    return Err(DistributionScopeMismatch(variable.name()))
  }
  if scope[0].size() != variable.size() {
    return Err(
      DistributionChildDomainMismatch(
        variable.name(),
        variable.size(),
        scope[0].size(),
      ),
    )
  }
  parent_index = 0
  while parent_index < parents.length() {
    if scope[parent_index + 1].name() != parents[parent_index] {
      return Err(DistributionScopeMismatch(variable.name()))
    }
    parent_index += 1
  }
  match validate_conditional_table(variable, distribution) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  Ok(NetworkNode::{ variable, parents: parents.copy(), distribution, })
}

///|
/// Returns the child variable.
pub fn NetworkNode::variable(self : NetworkNode) -> Variable {
  self.variable
}

///|
/// Returns the child variable name.
pub fn NetworkNode::variable_name(self : NetworkNode) -> String {
  self.variable.name()
}

///|
/// Returns the ordered parent names.
pub fn NetworkNode::parents(self : NetworkNode) -> Array[String] {
  self.parents.copy()
}

///|
/// Returns the local conditional probability table.
pub fn NetworkNode::distribution(self : NetworkNode) -> Factor {
  self.distribution
}

///|
/// An immutable discrete Bayesian network with a deterministic topological
/// variable order.
pub struct BayesianNetwork {
  priv nodes : Array[NetworkNode]
  priv order : Array[String]
}

///|
/// Creates a validated directed acyclic Bayesian network.
pub fn BayesianNetwork::new(
  nodes : Array[NetworkNode],
) -> Result[BayesianNetwork, NetworkError] {
  if nodes.length() == 0 {
    return Err(EmptyNetwork)
  }
  let mut index = 0
  while index < nodes.length() {
    let name = nodes[index].variable_name()
    let mut previous = 0
    while previous < index {
      if nodes[previous].variable_name() == name {
        return Err(DuplicateNode(name))
      }
      previous += 1
    }
    index += 1
  }
  index = 0
  while index < nodes.length() {
    let node = nodes[index]
    let parents = node.parents()
    for parent_name in parents {
      let parent = match find_network_node(nodes, parent_name) {
        Some(parent) => parent
        None => return Err(UnknownParent(parent_name))
      }
      let distribution_parent = match
        find_variable(node.distribution().scope(), parent_name) {
        Some(variable) => variable
        None => return Err(DistributionScopeMismatch(node.variable_name()))
      }
      if distribution_parent.size() != parent.variable().size() {
        return Err(
          DistributionParentDomainMismatch(
            node.variable_name(),
            parent_name,
            parent.variable().size(),
            distribution_parent.size(),
          ),
        )
      }
    }
    index += 1
  }
  let order = match topological_order(nodes) {
    Ok(order) => order
    Err(error) => return Err(error)
  }
  Ok(BayesianNetwork::{ nodes: nodes.copy(), order, })
}

///|
/// Returns the number of nodes.
pub fn BayesianNetwork::node_count(self : BayesianNetwork) -> Int32 {
  self.nodes.length()
}

///|
/// Returns a node by variable name.
pub fn BayesianNetwork::node(
  self : BayesianNetwork,
  name : String,
) -> NetworkNode? {
  find_network_node(self.nodes, name)
}

///|
/// Returns the ordered topological variable names.
pub fn BayesianNetwork::topological_order(
  self : BayesianNetwork,
) -> Array[String] {
  self.order.copy()
}

///|
/// Returns the ordered parent names for a node.
pub fn BayesianNetwork::parents_of(
  self : BayesianNetwork,
  name : String,
) -> Array[String]? {
  match find_network_node(self.nodes, name) {
    Some(node) => Some(node.parents())
    None => None
  }
}

///|
/// Returns the local conditional table for a node.
pub fn BayesianNetwork::distribution_of(
  self : BayesianNetwork,
  name : String,
) -> Result[Factor, NetworkError] {
  match find_network_node(self.nodes, name) {
    Some(node) => Ok(node.distribution())
    None => Err(UnknownNode(name))
  }
}

///|
fn validate_conditional_table(
  variable : Variable,
  distribution : Factor,
) -> Result[Unit, NetworkError] {
  let scope = distribution.scope()
  let parent_variables : Array[Variable] = []
  let mut position = 1
  while position < scope.length() {
    parent_variables.push(scope[position])
    position += 1
  }
  let parent_count = match factor_table_size(parent_variables) {
    Ok(count) => count
    Err(_) => return Err(DistributionScopeMismatch(variable.name()))
  }
  let child_size = variable.size()
  let table = distribution.values()
  let mut parent_index = 0
  while parent_index < parent_count {
    let parent_assignment = index_to_assignment(parent_variables, parent_index)
    let full_assignment = Array::make(scope.length(), 0)
    position = 1
    while position < scope.length() {
      full_assignment[position] = parent_assignment[position - 1]
      position += 1
    }
    let mut mass = 0.0
    let mut child_value = 0
    while child_value < child_size {
      full_assignment[0] = child_value
      mass += table[assignment_to_index(scope, full_assignment)]
      child_value += 1
    }
    if (mass - 1.0).abs() > 1.0e-9 {
      return Err(UnnormalizedConditional(variable.name(), mass))
    }
    parent_index += 1
  }
  Ok(())
}

///|
fn find_network_node(nodes : Array[NetworkNode], name : String) -> NetworkNode? {
  let mut index = 0
  while index < nodes.length() {
    if nodes[index].variable_name() == name {
      return Some(nodes[index])
    }
    index += 1
  }
  None
}

///|
fn topological_order(
  nodes : Array[NetworkNode],
) -> Result[Array[String], NetworkError] {
  let indegree = Array::make(nodes.length(), 0)
  let visited = Array::make(nodes.length(), false)
  let order : Array[String] = []
  let mut index = 0
  while index < nodes.length() {
    indegree[index] = nodes[index].parents().length()
    index += 1
  }
  let mut progress = true
  while order.length() < nodes.length() && progress {
    progress = false
    index = 0
    while index < nodes.length() {
      if !visited[index] && indegree[index] == 0 {
        visited[index] = true
        let name = nodes[index].variable_name()
        order.push(name)
        progress = true
        let mut child_index = 0
        while child_index < nodes.length() {
          if !visited[child_index] &&
            contains_name(nodes[child_index].parents(), name) {
            indegree[child_index] -= 1
          }
          child_index += 1
        }
        break
      }
      index += 1
    }
  }
  if order.length() != nodes.length() {
    Err(CycleDetected)
  } else {
    Ok(order)
  }
}

///|
fn contains_name(names : Array[String], name : String) -> Bool {
  for candidate in names {
    if candidate == name {
      return true
    }
  }
  false
}
