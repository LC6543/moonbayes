///|
priv suberror CliError {
  Io(String)
  Usage(String)
  Model(String)
}

///|
fn CliError::to_string(self : CliError) -> String {
  match self {
    Io(message) => "io error: " + message
    Usage(message) => "usage error: " + message
    Model(message) => "model error: " + message
  }
}

///|
priv struct CliOptions {
  targets : Array[String]
  evidence : Array[(String, Int32)]
}

///|
fn usage() -> String {
  (
    #|Usage:
    #|  moonbayes validate <model.json>
    #|  moonbayes export <model.json>
    #|  moonbayes query <model.json> --target <name> [--target <name> ...] [--evidence <name=value> ...]
    #|  moonbayes likelihood <model.json> [--evidence <name=value> ...]
    #|  moonbayes map <model.json> --target <name> [--target <name> ...] [--evidence <name=value> ...]
  )
}

///|
fn parse_options(
  args : Array[String],
  start : Int32,
) -> CliOptions raise CliError {
  let targets : Array[String] = []
  let evidence : Array[(String, Int32)] = []
  let mut index = start
  while index < args.length() {
    match args[index] {
      "--target" => {
        if index + 1 >= args.length() {
          raise Usage("--target requires a variable name")
        }
        targets.push(args[index + 1])
        index += 2
      }
      "--evidence" => {
        if index + 1 >= args.length() {
          raise Usage("--evidence requires name=value")
        }
        evidence.push(parse_evidence(args[index + 1]))
        index += 2
      }
      option => raise Usage("unknown option: " + option)
    }
  }
  CliOptions::{ targets, evidence, }
}

///|
fn parse_evidence(text : String) -> (String, Int32) raise CliError {
  let (name, value) = match text.split_once("=") {
    Some(pair) => pair
    None => raise Usage("evidence must use name=value: " + text)
  }
  if name == "" {
    raise Usage("evidence variable name must not be empty")
  }
  let parsed = @string.parse_int(value) catch {
    _ => raise Usage("evidence value must be an integer: " + value.to_owned())
  }
  (name.to_owned(), parsed)
}

///|
fn load_model(path : String) -> @bayes.BayesianNetwork raise CliError {
  let text = @fs.read_file_to_string(path) catch {
    @fs.IOError(message) => raise Io(message)
  }
  match @bayes.BayesianNetwork::from_json_string(text) {
    Ok(network) => network
    Err(error) => raise Model(error.message())
  }
}

///|
fn require_model_path(args : Array[String]) -> String raise CliError {
  if args.length() < 2 {
    raise Usage("expected a model path")
  }
  args[1]
}

///|
fn format_assignment(names : Array[String], values : Array[Int32]) -> String {
  let parts : Array[String] = []
  let mut index = 0
  while index < names.length() {
    parts.push(names[index] + "=" + values[index].to_string())
    index += 1
  }
  parts.join(", ")
}

///|
fn print_factor(factor : @bayes.Factor) -> Unit {
  let names = factor.variable_names()
  let mut index = 0
  while index < factor.value_count() {
    let assignment = factor.assignment_at(index).unwrap()
    println(
      "  " +
      format_assignment(names, assignment) +
      " = " +
      factor.value_at(assignment).unwrap().to_string(),
    )
    index += 1
  }
}

///|
fn run_command(args : Array[String]) -> Unit raise CliError {
  if args.length() == 0 ||
    args[0] == "help" ||
    args[0] == "--help" ||
    args[0] == "-h" {
    println(usage())
    return
  }
  let command = args[0]
  let path = require_model_path(args)
  let options = parse_options(args, 2)
  let network = load_model(path)
  match command {
    "validate" => {
      if options.targets.length() > 0 || options.evidence.length() > 0 {
        raise Usage("validate does not accept query options")
      }
      println("ok: " + path)
    }
    "export" => {
      if options.targets.length() > 0 || options.evidence.length() > 0 {
        raise Usage("export does not accept query options")
      }
      println(network.to_json_string())
    }
    "query" => {
      let posterior = match network.query(options.targets, options.evidence) {
        Ok(factor) => factor
        Err(error) => raise Usage(error.message())
      }
      print_factor(posterior)
    }
    "likelihood" => {
      if options.targets.length() > 0 {
        raise Usage("likelihood does not accept targets")
      }
      let likelihood = match network.evidence_likelihood(options.evidence) {
        Ok(result) => result
        Err(error) => raise Usage(error.message())
      }
      println("probability: " + likelihood.probability().to_string())
      println("log_probability: " + likelihood.log_probability().to_string())
    }
    "map" => {
      let result = match network.map(options.targets, options.evidence) {
        Ok(result) => result
        Err(error) => raise Usage(error.message())
      }
      let names : Array[String] = []
      let values : Array[Int32] = []
      for entry in result.assignment() {
        names.push(entry.0)
        values.push(entry.1)
      }
      println("assignment: " + format_assignment(names, values))
      println("probability: " + result.probability().to_string())
      println("log_probability: " + result.log_probability().to_string())
    }
    _ => raise Usage("unknown command: " + command)
  }
}

///|
fn main {
  let raw_args = @env.args()
  let args : Array[String] = if raw_args.length() == 0 {
    []
  } else {
    raw_args[1:].to_owned()
  }
  run_command(args) catch {
    error => {
      eprintln(error.to_string())
      @sys.exit(1)
    }
  }
}
