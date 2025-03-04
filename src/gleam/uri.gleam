//// Utilities for working with URIs
////
//// This module provides functions for working with URIs (for example, parsing
//// URIs or encoding query strings). The functions in this module are implemented
//// according to [RFC 3986](https://tools.ietf.org/html/rfc3986).
////
//// Query encoding (Form encoding) is defined in the w3c specification.
//// https://www.w3.org/TR/html52/sec-forms.html#urlencoded-form-data

import gleam/option.{None, Option, Some}
import gleam/string
import gleam/int
import gleam/list

if erlang {
  import gleam/result
  import gleam/dynamic.{Dynamic}
  import gleam/map
  import gleam/function
  import gleam/pair
}

/// Type representing holding the parsed components of an URI.
/// All components of a URI are optional, except the path.
///
pub type Uri {
  Uri(
    scheme: Option(String),
    userinfo: Option(String),
    host: Option(String),
    port: Option(Int),
    path: String,
    query: Option(String),
    fragment: Option(String),
  )
}

if erlang {
  pub external fn erl_parse(String) -> Dynamic =
    "uri_string" "parse"

  type UriKey {
    Scheme
    Userinfo
    Host
    Port
    Path
    Query
    Fragment
  }

  /// Parses a compliant URI string into the `Uri` Type.
  /// If the string is not a valid URI string then an error is returned.
  ///
  /// The opposite operation is `uri.to_string`
  ///
  /// ## Examples
  ///
  /// ```
  /// > parse("https://example.com:1234/a/b?query=true#fragment")
  ///
  /// Ok(Uri(scheme: Some("https"), ...))
  /// ```
  ///
  pub fn parse(string: String) -> Result(Uri, Nil) {
    try uri_map =
      dynamic.map(erl_parse(string))
      |> result.nil_error
    let get = fn(k: UriKey, decode_type: dynamic.Decoder(t)) -> Option(t) {
      uri_map
      |> map.get(dynamic.from(k))
      |> result.then(function.compose(decode_type, result.nil_error))
      |> option.from_result
    }

    let uri =
      Uri(
        scheme: get(Scheme, dynamic.string),
        userinfo: get(Userinfo, dynamic.string),
        host: get(Host, dynamic.string),
        port: get(Port, dynamic.int),
        path: option.unwrap(get(Path, dynamic.string), ""),
        query: get(Query, dynamic.string),
        fragment: get(Fragment, dynamic.string),
      )
    Ok(uri)
  }

  external fn erl_parse_query(String) -> Dynamic =
    "uri_string" "dissect_query"

  /// Parses an urlencoded query string into a list of key value pairs.
  /// Returns an error for invalid encoding.
  ///
  /// The opposite operation is `uri.query_to_string`.
  ///
  /// ## Examples
  ///
  /// ```
  /// > parse_query("a=1&b=2")
  ///
  /// Ok([#("a", "1"), #("b", "2")])
  /// ```
  ///
  pub fn parse_query(query: String) -> Result(List(#(String, String)), Nil) {
    let bool_value = fn(x) { result.map(dynamic.bool(x), fn(_) { "" }) }
    let query_param = dynamic.typed_tuple2(
      _,
      dynamic.string,
      dynamic.any(_, of: [dynamic.string, bool_value]),
    )

    query
    |> erl_parse_query
    |> dynamic.typed_list(of: query_param)
    |> result.nil_error
  }

  type Encoding {
    Utf8
  }

  type ErlQueryToStringOption {
    Encoding(Encoding)
  }

  external fn erl_query_to_string(
    List(#(String, String)),
    List(ErlQueryToStringOption),
  ) -> Dynamic =
    "uri_string" "compose_query"

  /// Encodes a list of key value pairs as a URI query string.
  ///
  /// The opposite operation is `uri.parse_query`.
  ///
  /// ## Examples
  ///
  /// ```
  /// > query_to_string([#("a", "1"), #("b", "2")])
  ///
  /// "a=1&b=2"
  /// ```
  ///
  pub fn query_to_string(query: List(#(String, String))) -> String {
    query
    |> erl_query_to_string([Encoding(Utf8)])
    |> dynamic.string
    |> result.unwrap("")
  }

  /// Encodes a string into a percent encoded representation.
  /// Note that this encodes space as +.
  ///
  /// ## Examples
  ///
  /// ```
  /// > percent_encode("100% great")
  ///
  /// "100%25+great"
  /// ```
  ///
  pub fn percent_encode(value: String) -> String {
    query_to_string([#("k", value)])
    |> string.replace(each: "k=", with: "")
  }

  /// Decodes a percent encoded string.
  ///
  /// ## Examples
  ///
  /// ```
  /// > percent_decode("100%25+great")
  ///
  /// Ok("100% great")
  /// ```
  ///
  pub fn percent_decode(value: String) -> Result(String, Nil) {
    string.concat(["k=", value])
    |> parse_query
    |> result.then(list.head)
    |> result.map(pair.second)
  }
}

fn do_remove_dot_segments(
  input: List(String),
  accumulator: List(String),
) -> List(String) {
  case input {
    [] -> list.reverse(accumulator)
    [segment, ..rest] -> {
      let accumulator = case segment, accumulator {
        "", accumulator -> accumulator
        ".", accumulator -> accumulator
        "..", [] -> []
        "..", [_, ..accumulator] -> accumulator
        segment, accumulator -> [segment, ..accumulator]
      }
      do_remove_dot_segments(rest, accumulator)
    }
  }
}

fn remove_dot_segments(input: List(String)) -> List(String) {
  do_remove_dot_segments(input, [])
}

/// Splits the path section of a URI into it's constituent segments.
///
/// Removes empty segments and resolves dot-segments as specified in
/// [section 5.2](https://www.ietf.org/rfc/rfc3986.html#section-5.2) of the RFC.
///
/// ## Examples
///
/// ```
/// > path_segments("/users/1")
///
/// ["users" ,"1"]
/// ```
///
pub fn path_segments(path: String) -> List(String) {
  remove_dot_segments(string.split(path, "/"))
}

/// Encodes a `Uri` value as a URI string.
///
/// The opposite operation is `uri.parse`.
///
/// ## Examples
///
/// ```
/// > let uri = Uri(Some("http"), None, Some("example.com"), ...)
/// > to_string(uri)
///
/// "https://example.com"
/// ```
///
pub fn to_string(uri: Uri) -> String {
  let parts = case uri.fragment {
    Some(fragment) -> ["#", fragment]
    _ -> []
  }
  let parts = case uri.query {
    Some(query) -> ["?", query, ..parts]
    _ -> parts
  }
  let parts = [uri.path, ..parts]
  let parts = case uri.host, string.starts_with(uri.path, "/") {
    Some(host), False if host != "" -> ["/", ..parts]
    _, _ -> parts
  }
  let parts = case uri.host, uri.port {
    Some(_), Some(port) -> [":", int.to_string(port), ..parts]
    _, _ -> parts
  }
  let parts = case uri.scheme, uri.userinfo, uri.host {
    Some(s), Some(u), Some(h) -> [s, "://", u, "@", h, ..parts]
    Some(s), None, Some(h) -> [s, "://", h, ..parts]
    Some(s), Some(_), None | Some(s), None, None -> [s, ":", ..parts]
    None, None, Some(h) -> ["//", h, ..parts]
    None, Some(_), None | None, None, None -> parts
  }
  string.concat(parts)
}

/// Fetches the origin of a uri
///
/// Return the origin of a uri as defined in
/// https://tools.ietf.org/html/rfc6454
///
/// The supported uri schemes are `http` and `https`
/// Urls without a scheme will return Error
///
/// ## Examples
///
/// ```
/// > assert Ok(uri) = parse("http://example.com/path?foo#bar")
/// > origin(uri)
///
/// Ok("http://example.com")
/// ```
///
pub fn origin(uri: Uri) -> Result(String, Nil) {
  let Uri(scheme: scheme, host: host, port: port, ..) = uri
  case scheme {
    Some("https") | Some("http") -> {
      let origin = Uri(scheme, None, host, port, "", None, None)
      Ok(to_string(origin))
    }
    _ -> Error(Nil)
  }
}

fn drop_last(elements: List(a)) -> List(a) {
  list.take(from: elements, up_to: list.length(elements) - 1)
}

fn join_segments(segments: List(String)) -> String {
  string.join(["", ..segments], "/")
}

/// Resolves a uri with respect to the given base uri
///
/// The base uri must be an absolute uri or this function will return an error.
/// The algorithm for merging uris is described in [RFC 3986](https://tools.ietf.org/html/rfc3986#section-5.2)
pub fn merge(base: Uri, relative: Uri) -> Result(Uri, Nil) {
  case base {
    Uri(scheme: Some(_), host: Some(_), ..) ->
      case relative {
        Uri(host: Some(_), ..) -> {
          let path =
            string.split(relative.path, "/")
            |> remove_dot_segments()
            |> join_segments()
          let resolved =
            Uri(
              option.or(relative.scheme, base.scheme),
              None,
              relative.host,
              relative.port,
              path,
              relative.query,
              relative.fragment,
            )
          Ok(resolved)
        }
        Uri(scheme: None, host: None, ..) -> {
          let #(new_path, new_query) = case relative.path {
            "" -> #(base.path, option.or(relative.query, base.query))
            _ -> {
              let path_segments = case string.starts_with(relative.path, "/") {
                True -> string.split(relative.path, "/")
                False ->
                  string.split(base.path, "/")
                  |> drop_last()
                  |> list.append(string.split(relative.path, "/"))
              }
              let path =
                path_segments
                |> remove_dot_segments()
                |> join_segments()
              #(path, relative.query)
            }
          }
          let resolved =
            Uri(
              base.scheme,
              None,
              base.host,
              base.port,
              new_path,
              new_query,
              relative.fragment,
            )
          Ok(resolved)
        }
      }
    _ -> Error(Nil)
  }
}
