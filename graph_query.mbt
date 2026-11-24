///|
/// Errors produced by Bayesian-network structure queries.
pub enum GraphQueryError {
  EmptySet
  UnknownNode(String)
  DuplicateSetMember(String)
  OverlappingSets(String)
}

///|
/// Returns a human-readable explanation of a structure-query error.
pub fn GraphQueryError::message(self : GraphQueryError) -> String {
  match self {
    EmptySet => "left and right query sets must not be empty"
    UnknownNode(name) => "node does not exist: " + name
    DuplicateSetMember(name) => "query set contains a duplicate: " + name
    OverlappingSets(name) => "query sets overlap at: " + name
  }
}

///|
/// Returns the strict ancestors of a node in topological order.
///
/// Returns `None` when the node does not exist.
pub fn BayesianNetwork::ancestors_of(
  self : BayesianNetwork,
  name : String,
) -> Array[String]? {
  if find_network_node(self.nodes, name) is None {
    return None
  }
  let closure = ancestor_closure(self, [name])
  let result : Array[String] = []
  for ordered_name in self.order {
    if ordered_name != name && contains_name(closure, ordered_name) {
      result.push(ordered_name)
    }
  }
  Some(result)
}

///|
/// Returns the strict descendants of a node in topological order.
///
/// Returns `None` when the node does not exist.
pub fn BayesianNetwork::descendants_of(
  self : BayesianNetwork,
  name : String,
) -> Array[String]? {
  if find_network_node(self.nodes, name) is None {
    return None
  }
  let closure = descendant_closure(self, [name])
  let result : Array[String] = []
  for ordered_name in self.order {
    if ordered_name != name && contains_name(closure, ordered_name) {
      result.push(ordered_name)
    }
  }
  Some(result)
}

///|
/// Tests whether `left` and `right` are d-separated given `given`.
///
/// The implementation moralizes the ancestral subgraph of all three sets,
/// removes conditioned nodes, and checks whether the two sides remain
/// connected. The three sets must be pairwise disjoint.
pub fn BayesianNetwork::is_d_separated(
  self : BayesianNetwork,
  left : Array[String],
  right : Array[String],
  given : Array[String],
) -> Result[Bool, GraphQueryError] {
  if left.length() == 0 || right.length() == 0 {
    return Err(EmptySet)
  }
  match validate_query_set(self, left) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  match validate_query_set(self, right) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  match validate_query_set(self, given) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  for name in left {
    if contains_name(right, name) || contains_name(given, name) {
      return Err(OverlappingSets(name))
    }
  }
  for name in right {
    if contains_name(given, name) {
      return Err(OverlappingSets(name))
    }
  }
  let seeds = concatenate_names(concatenate_names(left, right), given)
  let relevant = ancestor_closure(self, seeds)
  let adjacency = moral_adjacency(self, relevant)
  let conditioned = Array::make(relevant.length(), false)
  for name in given {
    let index = find_name_position(relevant, name)
    if index >= 0 {
      conditioned[index] = true
    }
  }
  let targets = Array::make(relevant.length(), false)
  for name in right {
    let index = find_name_position(relevant, name)
    if index >= 0 {
      targets[index] = true
    }
  }
  let visited = Array::make(relevant.length(), false)
  let queue : Array[Int32] = []
  for name in left {
    let index = find_name_position(relevant, name)
    if index >= 0 && !visited[index] {
      visited[index] = true
      queue.push(index)
    }
  }
  let mut head = 0
  while head < queue.length() {
    let current = queue[head]
    head += 1
    if targets[current] {
      return Ok(false)
    }
    for neighbor in adjacency[current] {
      if !conditioned[neighbor] && !visited[neighbor] {
        visited[neighbor] = true
        queue.push(neighbor)
      }
    }
  }
  Ok(true)
}

///|
fn validate_query_set(
  network : BayesianNetwork,
  names : Array[String],
) -> Result[Unit, GraphQueryError] {
  let mut index = 0
  while index < names.length() {
    let name = names[index]
    if find_network_node(network.nodes, name) is None {
      return Err(UnknownNode(name))
    }
    let mut previous = 0
    while previous < index {
      if names[previous] == name {
        return Err(DuplicateSetMember(name))
      }
      previous += 1
    }
    index += 1
  }
  Ok(())
}

///|
fn ancestor_closure(
  network : BayesianNetwork,
  seeds : Array[String],
) -> Array[String] {
  let included = seeds.copy()
  let mut changed = true
  while changed {
    changed = false
    for node in network.nodes {
      if contains_name(included, node.variable_name()) {
        for parent in node.parents() {
          if !contains_name(included, parent) {
            included.push(parent)
            changed = true
          }
        }
      }
    }
  }
  topological_subset(network, included)
}

///|
fn descendant_closure(
  network : BayesianNetwork,
  seeds : Array[String],
) -> Array[String] {
  let included = seeds.copy()
  let mut changed = true
  while changed {
    changed = false
    for node in network.nodes {
      if contains_name(included, node.variable_name()) {
        continue
      }
      for parent in node.parents() {
        if contains_name(included, parent) {
          included.push(node.variable_name())
          changed = true
          break
        }
      }
    }
  }
  topological_subset(network, included)
}

///|
fn topological_subset(
  network : BayesianNetwork,
  included : Array[String],
) -> Array[String] {
  let result : Array[String] = []
  for name in network.order {
    if contains_name(included, name) {
      result.push(name)
    }
  }
  result
}

///|
fn concatenate_names(
  left : Array[String],
  right : Array[String],
) -> Array[String] {
  let result = left.copy()
  for name in right {
    result.push(name)
  }
  result
}

///|
fn moral_adjacency(
  network : BayesianNetwork,
  relevant : Array[String],
) -> Array[Array[Int32]] {
  let adjacency = Array::makei(relevant.length(), _ => [])
  for node in network.nodes {
    let child = node.variable_name()
    if !contains_name(relevant, child) {
      continue
    }
    let parents = node.parents()
    for parent in parents {
      connect_undirected(adjacency, relevant, child, parent)
    }
    let mut left = 0
    while left < parents.length() {
      let mut right = left + 1
      while right < parents.length() {
        connect_undirected(adjacency, relevant, parents[left], parents[right])
        right += 1
      }
      left += 1
    }
  }
  adjacency
}

///|
fn connect_undirected(
  adjacency : Array[Array[Int32]],
  names : Array[String],
  left : String,
  right : String,
) -> Unit {
  let left_index = find_name_position(names, left)
  let right_index = find_name_position(names, right)
  if left_index < 0 || right_index < 0 || left_index == right_index {
    return
  }
  if !contains_index(adjacency[left_index], right_index) {
    adjacency[left_index].push(right_index)
  }
  if !contains_index(adjacency[right_index], left_index) {
    adjacency[right_index].push(left_index)
  }
}

///|
fn find_name_position(names : Array[String], name : String) -> Int32 {
  let mut index = 0
  while index < names.length() {
    if names[index] == name {
      return index
    }
    index += 1
  }
  -1
}

///|
fn contains_index(indices : Array[Int32], target : Int32) -> Bool {
  for index in indices {
    if index == target {
      return true
    }
  }
  false
}
