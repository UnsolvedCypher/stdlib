import gleam/result
import gleam/option.{Option}
import gleam/list

/// A dictionary of keys and values.
///
/// Any type can be used for the keys and values of a map, but all the keys
/// must be of the same type and all the values must be of the same type.
///
/// Each key can only be present in a map once.
///
/// Maps are not ordered in any way, and any unintentional ordering is not to
/// be relied upon in your code as it may change in future versions of Erlang
/// or Gleam.
///
/// See [the Erlang map module](https://erlang.org/doc/man/maps.html) for more
/// information.
///
pub external type Map(key, value)

/// Determines the number of key-value pairs in the map.
/// This function runs in constant time and does not need to iterate the map.
///
/// ## Examples
///
///    > new() |> size()
///    0
///
///    > new() |> insert("key", "value") |> size()
///    1
///
///
pub fn size(map: Map(k, v)) -> Int {
  do_size(map)
}

if erlang {
  external fn do_size(Map(k, v)) -> Int =
    "maps" "size"
}

if javascript {
  external fn do_size(Map(k, v)) -> Int =
    "../gleam_stdlib.js" "map_size"
}

/// Converts the map to a list of 2-element tuples `#(key, value)`, one for
/// each key-value pair in the map.
///
/// The tuples in the list have no specific order.
///
/// ## Examples
///
///    > new() |> to_list()
///    []
///
///    > new() |> insert("key", 0) |> to_list()
///    [#("key", 0)]
///
pub fn to_list(map: Map(key, value)) -> List(#(key, value)) {
  do_to_list(map)
}

if erlang {
  external fn do_to_list(Map(key, value)) -> List(#(key, value)) =
    "maps" "to_list"
}

if javascript {
  external fn do_to_list(Map(key, value)) -> List(#(key, value)) =
    "../gleam_stdlib.js" "map_to_list"
}

/// Converts a list of 2-element tuples `#(key, value)` to a map.
///
/// If two tuples have the same key the last one in the list will be the one
/// that is present in the map.
///
pub fn from_list(list: List(#(key, value))) -> Map(key, value) {
  do_from_list(list)
}

if erlang {
  external fn do_from_list(List(#(key, value))) -> Map(key, value) =
    "maps" "from_list"
}

if javascript {
  external fn do_from_list(List(#(key, value))) -> Map(key, value) =
    "../gleam_stdlib.js" "map_from_list"
}

/// Determines whether or not a value present in the map for a given key.
///
/// ## Examples
///
///    > new() |> insert("a", 0) |> has_key("a")
///    True
///
///    > new() |> insert("a", 0) |> has_key("b")
///    False
///
pub fn has_key(map: Map(k, v), key: k) -> Bool {
  do_has_key(key, map)
}

if erlang {
  external fn do_has_key(key, Map(key, v)) -> Bool =
    "maps" "is_key"
}

if javascript {
  external fn do_has_key(k, Map(k, v)) -> Bool =
    "../gleam_stdlib.js" "map_has_key"
}

/// Creates a fresh map that contains no values.
///
pub fn new() -> Map(key, value) {
  do_new()
}

if erlang {
  external fn do_new() -> Map(key, value) =
    "maps" "new"
}

if javascript {
  external fn do_new() -> Map(key, value) =
    "../gleam_stdlib.js" "new_map"
}

/// Fetches a value from a map for a given key.
///
/// The map may not have a value for the key, so the value is wrapped in a
/// Result.
///
/// ## Examples
///
///    > new() |> insert("a", 0) |> get("a")
///    Ok(0)
///
///    > new() |> insert("a", 0) |> get("b")
///    Error(Nil)
///
pub fn get(from: Map(key, value), get: key) -> Result(value, Nil) {
  do_get(from, get);
}

if erlang {
  external fn do_get(Map(key, value), key) -> Result(value, Nil) =
    "gleam_stdlib" "map_get"
}

if javascript {
  external fn do_get(Map(key, value), key) -> Result(value, Nil) =
    "../gleam_stdlib.js" "map_get"
}

/// Inserts a value into the map with the given key.
///
/// If the map already has a value for the given key then the value is
/// replaced with the new value.
///
/// ## Examples
///
///    > new() |> insert("a", 0) |> to_list
///    [#("a", 0)]
///
///    > new() |> insert("a", 0) |> insert("a", 5) |> to_list
///    [#("a", 5)]
///
pub fn insert(into map: Map(k, v), for key: k, insert value: v) -> Map(k, v) {
  do_insert(key, value, map)
}

if erlang {
  external fn do_insert(key, value, Map(key, value)) -> Map(key, value) =
    "maps" "put"
}

if javascript {
  external fn do_insert(key, value, Map(key, value)) -> Map(key, value) =
    "../gleam_stdlib.js" "map_insert"
}

/// Updates all values in a given map by calling a given function on each key
/// and value.
///
/// ## Examples
///
///    > [#(3, 3), #(2, 4)]
///    > |> from_list
///    > |> map_values(fn(key, value) { key * value })
///    [#(3, 9), #(2, 8)]
///
///
pub fn map_values(in map: Map(k, v), with fun: fn(k, v) -> w) -> Map(k, w) {
  do_map_values(fun, map)
}

if erlang {
  external fn do_map_values(fn(key, value) -> b, Map(key, value)) -> Map(key, b) =
    "maps" "map"
}

if javascript {
  external fn do_map_values(fn(key, value) -> b, Map(key, value)) -> Map(key, b) =
    "../gleam_stdlib.js" "map_map_values"
}

/// Gets a list of all keys in a given map.
///
/// Maps are not ordered so the keys are not returned in any specific order. Do
/// not write code that relies on the order keys are returned by this function
/// as it may change in later versions of Gleam or Erlang.
///
/// ## Examples
///
///    > keys([#("a", 0), #("b", 1)])
///    ["a", "b"]
///
pub fn keys(map: Map(keys, v)) -> List(keys) {
  do_keys(map)
}

if erlang {
  external fn do_keys(Map(keys, v)) -> List(keys) =
    "maps" "keys"
}

if javascript {
  external fn do_keys(Map(keys, v)) -> List(keys) =
    "../gleam_stdlib.js" "map_keys"
}

/// Gets a list of all values in a given map.
///
/// Maps are not ordered so the values are not returned in any specific order. Do
/// not write code that relies on the order values are returned by this function
/// as it may change in later versions of Gleam or Erlang.
///
/// ## Examples
///
///    > keys(from_list([#("a", 0), #("b", 1)]))
///    [0, 1]
///
pub fn values(map: Map(k, values)) -> List(values) {
  do_values(map)
}

if erlang {
  external fn do_values(Map(k, values)) -> List(values) =
    "maps" "values"
}

if javascript {
  external fn do_values(Map(k, values)) -> List(values) =
    "../gleam_stdlib.js" "map_values"
}

/// Creates a new map from a given map, minus any entries that a given function
/// returns False for.
///
/// ## Examples
///
///    > from_list([#("a", 0), #("b", 1)])
///    > |> filter(fn(key, value) { value != 0 })
///    from_list([#("b", 1)])
///
///    > from_list([#("a", 0), #("b", 1)])
///    > |> filter(fn(key, value) { True })
///    from_list([#("a", 0), #("b", 1)])
///
pub fn filter(in map: Map(k, v), for property: fn(k, v) -> Bool) -> Map(k, v) {
  do_filter(property, map)
}

if erlang {
  external fn do_filter(
    fn(key, value) -> Bool,
    Map(key, value),
  ) -> Map(key, value) =
    "maps" "filter"
}

if javascript {
  external fn do_filter(
    fn(key, value) -> Bool,
    Map(key, value),
  ) -> Map(key, value) =
    "../gleam_stdlib.js" "map_filter"
}

/// Creates a new map from a given map, only including any entries for which the
/// keys are in a given list.
///
/// ## Examples
///
///    > from_list([#("a", 0), #("b", 1)])
///    > |> take(["b"])
///    from_list([#("b", 1)])
///
///    > from_list([#("a", 0), #("b", 1)])
///    > |> take(["a", "b", "c"])
///    from_list([#("a", 0), #("b", 1)])
///
pub fn take(from map: Map(k, v), keeping desired_keys: List(k)) -> Map(k, v) {
  do_take(desired_keys, map)
}

if erlang {
 external fn do_take(List(k), Map(k, v)) -> Map(k, v) =
  "maps" "with"
}

if javascript {
 external fn do_take(List(k), Map(k, v)) -> Map(k, v) =
  "../gleam_stdlib.js" "map_take"
}

/// Creates a new map from a pair of given maps by combining their entries.
///
/// If there are entries with the same keys in both maps the entry from the
/// second map takes precedence.
///
/// ## Examples
///
///    > let a = from_list([#("a", 0), #("b", 1)])
///    > let b = from_list([#("b", 2), #("c", 3)])
///    > merge(a, b)
///    from_list([#("a", 0), #("b", 2), #("c", 3)])
///
pub fn merge(into: Map(k, v), merge: Map(k, v)) -> Map(k, v) {
  do_merge(into, merge)
}

if erlang {
  external fn do_merge(into: Map(k, v), merge: Map(k, v)) -> Map(k, v) =
    "maps" "merge"
}

if javascript {
  external fn do_merge(into: Map(k, v), merge: Map(k, v)) -> Map(k, v) =
    "../gleam_stdlib.js" "map_merge"
}

/// Creates a new map from a given map with all the same entries except for the
/// one with a given key, if it exists.
///
/// ## Examples
///
///    > delete([#("a", 0), #("b", 1)], "a")
///    from_list([#("b", 1)])
///
///    > delete([#("a", 0), #("b", 1)], "c")
///    from_list([#("a", 0), #("b", 1)])
///
pub fn delete(from map: Map(k, v), delete key: k) -> Map(k, v) {
  do_delete(key, map)
}

if erlang {
  external fn do_delete(k, Map(k, v)) -> Map(k, v) =
    "maps" "remove"
}

if javascript {
  external fn do_delete(k, Map(k, v)) -> Map(k, v) =
    "../gleam_stdlib.js" "map_remove"
}

/// Creates a new map from a given map with all the same entries except any with
/// keys found in a given list.
///
/// ## Examples
///
///    > drop([#("a", 0), #("b", 1)], ["a"])
///    from_list([#("b", 2)])
///
///    > delete([#("a", 0), #("b", 1)], ["c"])
///    from_list([#("a", 0), #("b", 1)])
///
///    > drop([#("a", 0), #("b", 1)], ["a", "b", "c"])
///    from_list([])
///
pub fn drop(from map: Map(k, v), drop disallowed_keys: List(k)) -> Map(k, v) {
  list.fold(disallowed_keys, map, fn(key, acc) { delete(acc, key) })
}

/// Creates a new map with one entry updated using a given function.
///
/// If there was not an entry in the map for the given key then the function
/// gets `Error(Nil)` as its argument, otherwise it gets `Ok(value)`.
///
/// ## Example
///
///    > let increment = fn(x) {
///    >   case x {
///    >     Ok(i) -> i + 1
///    >     Error(Nil) -> 0
///    >   }
///    > }
///    > let map = from_list([#("a", 0)])
///    >
///    > update(map, "a" increment)
///    from_list([#("a", 1)])
///
///    > update(map, "b" increment)
///    from_list([#("a", 0), #("b", 0)])
///
pub fn update(
  in map: Map(k, v),
  update key: k,
  with fun: fn(Option(v)) -> v,
) -> Map(k, v) {
  map
  |> get(key)
  |> option.from_result
  |> fun
  |> insert(map, key, _)
}

fn do_fold(
  list: List(#(k, v)),
  initial: acc,
  fun: fn(k, v, acc) -> acc,
) -> acc {
  case list {
    [] -> initial
    [#(k, v), ..tail] -> do_fold(tail, fun(k, v, initial), fun)
  }
}

/// Combines all entries into a single value by calling a given function on each
/// one.
///
/// Maps are not ordered so the values are not returned in any specific order. Do
/// not write code that relies on the order entries are used by this function
/// as it may change in later versions of Gleam or Erlang.
///
/// # Examples
///
///    > let map = from_list([#("a", 1), #("b", 3), #("c", 9)])
///    > fold(map, 0, fn(key, value, accumulator) { accumulator + value })
///    13
///
///    > import gleam/string.{append}
///    > fold(map, "", fn(key, value, accumulator) { append(accumulator, value) })
///    "abc"
///
pub fn fold(
  over map: Map(k, v),
  from initial: acc,
  with fun: fn(k, v, acc) -> acc,
) -> acc {
  map
  |> to_list
  |> do_fold(initial, fun)
}
