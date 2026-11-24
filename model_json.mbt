///|
/// The current JSON model format version.
pub const MODEL_FORMAT_VERSION : Int32 = 1

///|
/// Serializes this network to a versioned JSON value.
pub fn BayesianNetwork::to_json(self : BayesianNetwork) -> Json {
  let nodes = Array::makei(self.nodes.length(), index => {
    network_node_to_json(self.nodes[index])
  })
  Json::object({
    "format": Json::string("moonbayes"),
    "version": Json::number(MODEL_FORMAT_VERSION.to_double()),
    "nodes": Json::array(nodes),
  })
}

///|
/// Serializes this network to indented JSON text.
pub fn BayesianNetwork::to_json_string(self : BayesianNetwork) -> String {
  self.to_json().stringify(indent=2)
}

///|
/// Parses a network from JSON text.
pub fn BayesianNetwork::from_json_string(
  text : String,
) -> Result[BayesianNetwork, NetworkError] {
  let value = @json.parse(text) catch {
    error => return Err(InvalidJson(error.to_string()))
  }
  BayesianNetwork::from_json(value)
}

///|
/// Parses a network from a versioned JSON value.
pub fn BayesianNetwork::from_json(
  value : Json,
) -> Result[BayesianNetwork, NetworkError] {
  let object = match json_object(value) {
    Some(object) => object
    None => return Err(InvalidField("root"))
  }
  let format = match required_string(object, "format", "format") {
    Some(format) => format
    None => return Err(InvalidField("format"))
  }
  if format != "moonbayes" {
    return Err(InvalidModelFormat)
  }
  let version = match required_int32(object, "version", "version") {
    Some(version) => version
    None => return Err(InvalidField("version"))
  }
  if version != MODEL_FORMAT_VERSION {
    return Err(UnsupportedFormatVersion(version))
  }
  let node_values = match required_array(object, "nodes", "nodes") {
    Some(nodes) => nodes
    None => return Err(InvalidField("nodes"))
  }
  let nodes : Array[NetworkNode] = []
  let mut index = 0
  while index < node_values.length() {
    let node = match parse_network_node(node_values[index], index) {
      Ok(node) => node
      Err(error) => return Err(error)
    }
    nodes.push(node)
    index += 1
  }
  BayesianNetwork::new(nodes)
}

///|
fn network_node_to_json(node : NetworkNode) -> Json {
  let parents = node.parents()
  let parent_values = Array::makei(parents.length(), index => {
    Json::string(parents[index])
  })
  Json::object({
    "variable": variable_to_json(node.variable()),
    "parents": Json::array(parent_values),
    "distribution": factor_to_json(node.distribution()),
  })
}

///|
fn variable_to_json(variable : Variable) -> Json {
  Json::object({
    "name": Json::string(variable.name()),
    "domain": Json::number(variable.size().to_double()),
  })
}

///|
fn factor_to_json(factor : Factor) -> Json {
  let variables = factor.scope()
  let values = factor.values()
  Json::object({
    "variables": Json::array(
      Array::makei(variables.length(), index => {
        variable_to_json(variables[index])
      }),
    ),
    "values": Json::array(
      Array::makei(values.length(), index => Json::number(values[index])),
    ),
  })
}

///|
fn parse_network_node(
  value : Json,
  node_index : Int32,
) -> Result[NetworkNode, NetworkError] {
  let object = match json_object(value) {
    Some(object) => object
    None => return Err(InvalidField(node_path(node_index)))
  }
  let variable_value = match object.get("variable") {
    Some(value) => value
    None => return Err(InvalidField(node_path(node_index) + ".variable"))
  }
  let variable = match parse_variable(variable_value, node_index) {
    Ok(variable) => variable
    Err(error) => return Err(error)
  }
  let parent_values = match required_array(object, "parents", "nodes.parents") {
    Some(values) => values
    None => return Err(InvalidField(node_path(node_index) + ".parents"))
  }
  let parents : Array[String] = []
  let mut index = 0
  while index < parent_values.length() {
    let parent = match json_string(parent_values[index]) {
      Some(parent) => parent
      None =>
        return Err(
          InvalidField(
            node_path(node_index) + ".parents[" + index.to_string() + "]",
          ),
        )
    }
    parents.push(parent)
    index += 1
  }
  let distribution_value = match object.get("distribution") {
    Some(value) => value
    None => return Err(InvalidField(node_path(node_index) + ".distribution"))
  }
  let distribution = match parse_factor(distribution_value, node_index) {
    Ok(factor) => factor
    Err(error) => return Err(error)
  }
  NetworkNode::new(variable, parents, distribution)
}

///|
fn parse_variable(
  value : Json,
  node_index : Int32,
) -> Result[Variable, NetworkError] {
  let object = match json_object(value) {
    Some(object) => object
    None => return Err(InvalidField(node_path(node_index) + ".variable"))
  }
  let name = match required_string(object, "name", "nodes.variable.name") {
    Some(name) => name
    None => return Err(InvalidField(node_path(node_index) + ".variable.name"))
  }
  let domain = match required_int32(object, "domain", "nodes.variable.domain") {
    Some(domain) => domain
    None => return Err(InvalidField(node_path(node_index) + ".variable.domain"))
  }
  match Variable::new(name, domain) {
    Ok(variable) => Ok(variable)
    Err(error) => Err(FactorFailure(error))
  }
}

///|
fn parse_factor(
  value : Json,
  node_index : Int32,
) -> Result[Factor, NetworkError] {
  let object = match json_object(value) {
    Some(object) => object
    None => return Err(InvalidField(node_path(node_index) + ".distribution"))
  }
  let variable_values = match object.get("variables") {
    Some(Json::Array(values)) => values
    _ =>
      return Err(
        InvalidField(node_path(node_index) + ".distribution.variables"),
      )
  }
  let variables : Array[Variable] = []
  let mut index = 0
  while index < variable_values.length() {
    let variable = match parse_variable(variable_values[index], node_index) {
      Ok(variable) => variable
      Err(error) => return Err(error)
    }
    variables.push(variable)
    index += 1
  }
  let value_values = match object.get("values") {
    Some(Json::Array(values)) => values
    _ =>
      return Err(InvalidField(node_path(node_index) + ".distribution.values"))
  }
  let values = Array::make(value_values.length(), 0.0)
  index = 0
  while index < value_values.length() {
    let number = match json_number(value_values[index]) {
      Some(number) => number
      None =>
        return Err(
          InvalidField(
            node_path(node_index) +
            ".distribution.values[" +
            index.to_string() +
            "]",
          ),
        )
    }
    values[index] = number
    index += 1
  }
  match Factor::new(variables, values) {
    Ok(factor) => Ok(factor)
    Err(error) => Err(FactorFailure(error))
  }
}

///|
fn node_path(index : Int32) -> String {
  "nodes[" + index.to_string() + "]"
}

///|
fn json_object(value : Json) -> Map[String, Json]? {
  match value {
    Json::Object(object) => Some(object)
    _ => None
  }
}

///|
fn json_array(value : Json) -> Array[Json]? {
  match value {
    Json::Array(values) => Some(values)
    _ => None
  }
}

///|
fn json_string(value : Json) -> String? {
  match value {
    Json::String(text) => Some(text)
    _ => None
  }
}

///|
fn json_number(value : Json) -> Double? {
  match value {
    Json::Number(number, ..) => Some(number)
    _ => None
  }
}

///|
fn json_int32(value : Json) -> Int32? {
  let number = match json_number(value) {
    Some(number) => number
    None => return None
  }
  if number.is_nan() ||
    number.is_inf() ||
    number.floor() != number ||
    number < -2147483648.0 ||
    number > 2147483647.0 {
    None
  } else {
    Some(number.to_int())
  }
}

///|
fn required_string(
  object : Map[String, Json],
  key : String,
  _path : String,
) -> String? {
  match object.get(key) {
    Some(value) => json_string(value)
    None => None
  }
}

///|
fn required_int32(
  object : Map[String, Json],
  key : String,
  _path : String,
) -> Int32? {
  match object.get(key) {
    Some(value) => json_int32(value)
    None => None
  }
}

///|
fn required_array(
  object : Map[String, Json],
  key : String,
  _path : String,
) -> Array[Json]? {
  match object.get(key) {
    Some(value) => json_array(value)
    None => None
  }
}
