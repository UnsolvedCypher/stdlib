import gleam/list

if erlang {
  import gleam/option.{None, Option, Some}
  import gleam/map.{Map}
}

// Internal private representation of an Iterator
type Action(element) {
  Stop
  Continue(element, fn() -> Action(element))
}

/// An iterator is a lazily evaluated sequence of element.
///
/// Iterators are useful when working with collections that are too large to
/// fit in memory (or those that are infinite in size) as they only require the
/// elements currently being processed to be in memory.
///
/// As a lazy data structure no work is done when an iterator is filters,
/// mapped, etc, instead a new iterator is returned with these transformations
/// applied to the stream. Once the stream has all the required transformations
/// applied it can be evaluated using functions such as `fold` and `to_list`.
///
pub opaque type Iterator(element) {
  Iterator(continuation: fn() -> Action(element))
}

// Public API for iteration
pub type Step(element, accumulator) {
  Next(element: element, accumulator: accumulator)
  Done
}

// Shortcut for an empty iterator.
fn stop() -> Action(element) {
  Stop
}

// Creating Iterators
fn do_unfold(
  initial: acc,
  f: fn(acc) -> Step(element, acc),
) -> fn() -> Action(element) {
  fn() {
    case f(initial) {
      Next(x, acc) -> Continue(x, do_unfold(acc, f))
      Done -> Stop
    }
  }
}

/// Creates an iterator from a given function and accumulator.
///
/// The function is called on the accumulator and returns either `Done`,
/// indicating the iterator has no more elements, or `Next` which contains a
/// new element and accumulator. The element is yielded by the iterator and the
/// new accumulator is used with the function to compute the next element in
/// the sequence.
///
/// ## Examples
///
///    > unfold(from: 5, with: fn(n) {
///    >  case n {
///    >    0 -> Done
///    >    n -> Next(element: n, accumulator: n - 1)
///    >  }
///    > })
///    > |> to_list
///    [5, 4, 3, 2, 1]
///
pub fn unfold(
  from initial: acc,
  with f: fn(acc) -> Step(element, acc),
) -> Iterator(element) {
  initial
  |> do_unfold(f)
  |> Iterator
}

// TODO: test
/// Creates an iterator that yields values created by calling a given function
/// repeatedly.
///
pub fn repeatedly(f: fn() -> element) -> Iterator(element) {
  unfold(Nil, fn(_) { Next(f(), Nil) })
}

/// Creates an iterator that returns the same value infinitely.
///
/// ## Examples
///
///    > repeat(10)
///    > |> take(4)
///    > |> to_list
///    [10, 10, 10, 10]
///
pub fn repeat(x: element) -> Iterator(element) {
  repeatedly(fn() { x })
}

/// Creates an iterator that yields each element from the given list.
///
/// ## Examples
///
///    > from_list([1, 2, 3, 4]) |> to_list
///    [1, 2, 3, 4]
///
pub fn from_list(list: List(element)) -> Iterator(element) {
  let yield = fn(acc) {
    case acc {
      [] -> Done
      [head, ..tail] -> Next(head, tail)
    }
  }
  unfold(list, yield)
}

// Consuming Iterators
fn do_fold(
  continuation: fn() -> Action(e),
  f: fn(e, acc) -> acc,
  accumulator: acc,
) -> acc {
  case continuation() {
    Continue(elem, next) -> do_fold(next, f, f(elem, accumulator))
    Stop -> accumulator
  }
}

/// Reduces an iterator of elements into a single value by calling a given
/// function on each element in turn.
///
/// If called on an iterator of infinite length then this function will never
/// return.
///
/// If you do not care about the end value and only wish to evaluate the
/// iterator for side effects consider using the `run` function instead.
///
/// ## Examples
///
///    > [1, 2, 3, 4]
///    > |> from_list
///    > |> fold(from: 0, with: fn(element, acc) { element + acc })
///    10
///
pub fn fold(
  over iterator: Iterator(e),
  from initial: acc,
  with f: fn(e, acc) -> acc,
) -> acc {
  iterator.continuation
  |> do_fold(f, initial)
}

// TODO: test
/// Evaluates all elements emitted by the given iterator. This function is useful for when
/// you wish to trigger any side effects that would occur when evaluating
/// the iterator.
///
pub fn run(iterator: Iterator(e)) -> Nil {
  fold(iterator, Nil, fn(_, _) { Nil })
}

/// Evaluates an iterator and returns all the elements as a list.
///
/// If called on an iterator of infinite length then this function will never
/// return.
///
/// ## Examples
///
///   > [1, 2, 3] |> from_list |> map(fn(x) { x * 2 }) |> to_list
///   [2, 4, 6]
///
pub fn to_list(iterator: Iterator(element)) -> List(element) {
  iterator
  |> fold([], fn(e, acc) { [e, ..acc] })
  |> list.reverse
}

/// Eagerly accesses the first value of an interator, returning a `Next`
/// that contains the first value and the rest of the iterator.
///
/// If called on an empty iterator, `Done` is returned.
///
/// ## Examples
///
///    > assert Next(head, tail) =
///    >   [1, 2, 3, 4]
///    >   |> from_list
///    >   |> step
///    > head
///    1
///
///    > tail |> to_list
///    [2, 3, 4]
///
///    > empty() |> step
///    Done
///
pub fn step(iterator: Iterator(e)) -> Step(e, Iterator(e)) {
  case iterator.continuation() {
    Stop -> Done
    Continue(e, a) -> Next(e, Iterator(a))
  }
}

fn do_take(continuation: fn() -> Action(e), desired: Int) -> fn() -> Action(e) {
  fn() {
    case desired > 0 {
      False -> Stop
      True ->
        case continuation() {
          Stop -> Stop
          Continue(e, next) -> Continue(e, do_take(next, desired - 1))
        }
    }
  }
}

/// Creates an iterator that only yields the first `desired` elements.
///
/// If the iterator does not have enough elements all of them are yielded.
///
/// ## Examples
///
///    > [1, 2, 3, 4, 5] |> from_list |> take(up_to: 3) |> to_list
///    [1, 2, 3]
///
///    > [1, 2] |> from_list |> take(up_to: 3) |> to_list
///    [1, 2]
///
pub fn take(from iterator: Iterator(e), up_to desired: Int) -> Iterator(e) {
  iterator.continuation
  |> do_take(desired)
  |> Iterator
}

fn do_drop(continuation: fn() -> Action(e), desired: Int) -> Action(e) {
  case continuation() {
    Stop -> Stop
    Continue(e, next) ->
      case desired > 0 {
        True -> do_drop(next, desired - 1)
        False -> Continue(e, next)
      }
  }
}

/// Evaluates and discards the first N elements in an iterator, returning a new
/// iterator.
///
/// If the iterator does not have enough elements an empty iterator is
/// returned.
///
/// This function does not evaluate the elements of the iterator, the
/// computation is performed when the iterator is later run.
///
/// ## Examples
///
///    > [1, 2, 3, 4, 5] |> from_list |> drop(up_to: 3) |> to_list
///    [4, 5]
///
///    > [1, 2] |> from_list |> drop(up_to: 3) |> to_list
///    []
///
pub fn drop(from iterator: Iterator(e), up_to desired: Int) -> Iterator(e) {
  fn() { do_drop(iterator.continuation, desired) }
  |> Iterator
}

fn do_map(continuation: fn() -> Action(a), f: fn(a) -> b) -> fn() -> Action(b) {
  fn() {
    case continuation() {
      Stop -> Stop
      Continue(e, continuation) -> Continue(f(e), do_map(continuation, f))
    }
  }
}

/// Creates an iterator from an existing iterator and a transformation function.
///
/// Each element in the new iterator will be the result of calling the given
/// function on the elements in the given iterator.
///
/// This function does not evaluate the elements of the iterator, the
/// computation is performed when the iterator is later run.
///
/// ## Examples
///
///    > [1, 2, 3] |> from_list |> map(fn(x) { x * 2 }) |> to_list
///    [2, 4, 6]
///
pub fn map(over iterator: Iterator(a), with f: fn(a) -> b) -> Iterator(b) {
  iterator.continuation
  |> do_map(f)
  |> Iterator
}

fn do_append(first: fn() -> Action(a), second: fn() -> Action(a)) -> Action(a) {
  case first() {
    Continue(e, first) -> Continue(e, fn() { do_append(first, second) })
    Stop -> second()
  }
}

/// Appends two iterators, producing a new iterator.
///
/// This function does not evaluate the elements of the iterators, the
/// computation is performed when the resulting iterator is later run.
///
/// ## Examples
///
///    > [1, 2] |> from_list |> append([3, 4] |> from_list) |> to_list
///    [1, 2, 3, 4]
///
pub fn append(to first: Iterator(a), suffix second: Iterator(a)) -> Iterator(a) {
  fn() { do_append(first.continuation, second.continuation) }
  |> Iterator
}

fn do_flatten(flattened: fn() -> Action(Iterator(a))) -> Action(a) {
  case flattened() {
    Stop -> Stop
    Continue(it, next_iterator) ->
      do_append(it.continuation, fn() { do_flatten(next_iterator) })
  }
}

/// Flattens an iterator of iterators, creating a new iterator.
///
/// This function does not evaluate the elements of the iterator, the
/// computation is performed when the iterator is later run.
///
/// ## Examples
///
///    > from_list([[1, 2], [3, 4]]) |> map(from_list) |> flatten |> to_list
///    [1, 2, 3, 4]
///
pub fn flatten(iterator: Iterator(Iterator(a))) -> Iterator(a) {
  fn() { do_flatten(iterator.continuation) }
  |> Iterator
}

/// Creates an iterator from an existing iterator and a transformation function.
///
/// Each element in the new iterator will be the result of calling the given
/// function on the elements in the given iterator and then flattening the
/// results.
///
/// This function does not evaluate the elements of the iterator, the
/// computation is performed when the iterator is later run.
///
/// ## Examples
///
///    > [1, 2] |> from_list |> flat_map(fn(x) { from_list([x, x + 1]) }) |> to_list
///    [1, 2, 2, 3]
///
pub fn flat_map(
  over iterator: Iterator(a),
  with f: fn(a) -> Iterator(b),
) -> Iterator(b) {
  iterator
  |> map(f)
  |> flatten
}

fn do_filter(
  continuation: fn() -> Action(e),
  predicate: fn(e) -> Bool,
) -> Action(e) {
  case continuation() {
    Stop -> Stop
    Continue(e, iterator) ->
      case predicate(e) {
        True -> Continue(e, fn() { do_filter(iterator, predicate) })
        False -> do_filter(iterator, predicate)
      }
  }
}

/// Creates an iterator from an existing iterator and a predicate function.
///
/// The new iterator will contain elements from the first iterator for which
/// the given function returns `True`.
///
/// This function does not evaluate the elements of the iterator, the
/// computation is performed when the iterator is later run.
///
/// ## Examples
///
///    > import gleam/int
///    > [1, 2, 3, 4] |> from_list |> filter(int.is_even) |> to_list
///    [2, 4]
///
pub fn filter(
  iterator: Iterator(a),
  for predicate: fn(a) -> Bool,
) -> Iterator(a) {
  fn() { do_filter(iterator.continuation, predicate) }
  |> Iterator
}

/// Creates an iterator that repeats a given iterator infinitely.
///
/// ## Examples
///
///    > [1, 2] |> from_list |> cycle |> take(6) |> to_list
///    [1, 2, 1, 2, 1, 2]
///
pub fn cycle(iterator: Iterator(a)) -> Iterator(a) {
  repeat(iterator)
  |> flatten
}

/// Creates an iterator of ints, starting at a given start int and stepping by
/// one to a given end int.
///
/// ## Examples
///
///    > range(from: 1, to: 5) |> to_list
///    [1, 2, 3, 4]
///
///    > range(from: 1, to: -2) |> to_list
///    [1, 0, -1]
///
///    > range(from: 0, to: 0) |> to_list
///    []
///
pub fn range(from start: Int, to stop: Int) -> Iterator(Int) {
  let increment = case start < stop {
    True -> 1
    False -> -1
  }

  let next_step = fn(current) {
    case current == stop {
      True -> Done
      False -> Next(current, current + increment)
    }
  }

  unfold(start, next_step)
}

fn do_find(continuation: fn() -> Action(a), f: fn(a) -> Bool) -> Result(a, Nil) {
  case continuation() {
    Stop -> Error(Nil)
    Continue(e, next) ->
      case f(e) {
        True -> Ok(e)
        False -> do_find(next, f)
      }
  }
}

/// Finds the first element in a given iterator for which the given function returns
/// True.
///
/// Returns `Error(Nil)` if the function does not return True for any of the
/// elements.
///
/// ## Examples
///
///    > find(from_list([1, 2, 3]), fn(x) { x > 2 })
///    Ok(3)
///
///    > find(from_list([1, 2, 3]), fn(x) { x > 4 })
///    Error(Nil)
///
///    > find(empty(), fn(_) { True })
///    Error(Nil)
///
pub fn find(
  in haystack: Iterator(a),
  one_that is_desired: fn(a) -> Bool,
) -> Result(a, Nil) {
  haystack.continuation
  |> do_find(is_desired)
}

fn do_index(
  continuation: fn() -> Action(element),
  next: Int,
) -> fn() -> Action(#(Int, element)) {
  fn() {
    case continuation() {
      Stop -> Stop
      Continue(e, continuation) ->
        Continue(#(next, e), do_index(continuation, next + 1))
    }
  }
}

/// Wraps values yielded from an iterator with indices, starting from 0.
///
/// ## Examples
///
///    > from_list(["a", "b", "c"]) |> index |> to_list
///    [#(0, "a"), #(1, "b"), #(2, "c")]
///
pub fn index(over iterator: Iterator(element)) -> Iterator(#(Int, element)) {
  iterator.continuation
  |> do_index(0)
  |> Iterator
}

/// Creates an iterator that inifinitely applies a function to a value.
///
/// ## Examples
///
///    > iterate(1, fn(n) { n * 3 }) |> take(5) |> to_list
///    [1, 3, 9, 27, 81]
///
pub fn iterate(
  from initial: element,
  with f: fn(element) -> element,
) -> Iterator(element) {
  unfold(initial, fn(element) { Next(element, f(element)) })
}

fn do_take_while(
  continuation: fn() -> Action(element),
  predicate: fn(element) -> Bool,
) -> fn() -> Action(element) {
  fn() {
    case continuation() {
      Stop -> Stop
      Continue(e, next) ->
        case predicate(e) {
          False -> Stop
          True -> Continue(e, do_take_while(next, predicate))
        }
    }
  }
}

/// Creates an iterator that yields elements while the predicate returns `True`.
///
/// ## Examples
///
///    > from_list([1, 2, 3, 2, 4]) |> take_while(satisfying: fn(x) { x < 3 }) |> to_list
///    [1, 2]
///
pub fn take_while(
  in iterator: Iterator(element),
  satisfying predicate: fn(element) -> Bool,
) -> Iterator(element) {
  iterator.continuation
  |> do_take_while(predicate)
  |> Iterator
}

fn do_drop_while(
  continuation: fn() -> Action(element),
  predicate: fn(element) -> Bool,
) -> Action(element) {
  case continuation() {
    Stop -> Stop
    Continue(e, next) ->
      case predicate(e) {
        False -> Continue(e, next)
        True -> do_drop_while(next, predicate)
      }
  }
}

/// Creates an iterator that drops elements while the predicate returns `True`,
/// and then yields the remaining elements.
///
/// ## Examples
///
///    > from_list([1, 2, 3, 4, 2, 5]) |> drop_while(satisfying: fn(x) { x < 4 }) |> to_list
///    [4, 2, 5]
///
pub fn drop_while(
  in iterator: Iterator(element),
  satisfying predicate: fn(element) -> Bool,
) -> Iterator(element) {
  fn() { do_drop_while(iterator.continuation, predicate) }
  |> Iterator
}

fn do_scan(
  continuation: fn() -> Action(element),
  f: fn(element, acc) -> acc,
  accumulator: acc,
) -> fn() -> Action(acc) {
  fn() {
    case continuation() {
      Stop -> Stop
      Continue(el, next) -> {
        let accumulated = f(el, accumulator)
        Continue(accumulated, do_scan(next, f, accumulated))
      }
    }
  }
}

/// Creates an iterator from an existing iterator and a stateful function.
///
/// Specifically, this behaves like `fold`, but yields intermediate results.
///
/// ## Examples
///
///    Generate a sequence of partial sums:
///    > from_list([1, 2, 3, 4, 5]) |> scan(from: 0, with: fn(el, acc) { acc + el }) |> to_list
///    [1, 3, 6, 10, 15]
///
pub fn scan(
  over iterator: Iterator(element),
  from initial: acc,
  with f: fn(element, acc) -> acc,
) -> Iterator(acc) {
  iterator.continuation
  |> do_scan(f, initial)
  |> Iterator
}

fn do_zip(
  left: fn() -> Action(a),
  right: fn() -> Action(b),
) -> fn() -> Action(#(a, b)) {
  fn() {
    case left() {
      Stop -> Stop
      Continue(el_left, next_left) ->
        case right() {
          Stop -> Stop
          Continue(el_right, next_right) ->
            Continue(#(el_left, el_right), do_zip(next_left, next_right))
        }
    }
  }
}

/// Zips two iterators together, emitting values from both
/// until the shorter one runs out.
///
/// ## Examples
///
///    > from_list(["a", "b", "c"]) |> zip(range(20, 30)) |> to_list
///    [#("a", 20), #("b", 21), #("c", 22)]
///
pub fn zip(left: Iterator(a), right: Iterator(b)) -> Iterator(#(a, b)) {
  do_zip(left.continuation, right.continuation)
  |> Iterator
}

// Result of collecting a single chunk by key
type Chunk(element, key) {
  AnotherBy(List(element), key, element, fn() -> Action(element))
  LastBy(List(element))
}

fn next_chunk(
  continuation: fn() -> Action(element),
  f: fn(element) -> key,
  previous_key: key,
  current_chunk: List(element),
) -> Chunk(element, key) {
  case continuation() {
    Stop -> LastBy(list.reverse(current_chunk))
    Continue(e, next) -> {
      let key = f(e)
      case key == previous_key {
        True -> next_chunk(next, f, key, [e, ..current_chunk])
        False -> AnotherBy(list.reverse(current_chunk), key, e, next)
      }
    }
  }
}

fn do_chunk(
  continuation: fn() -> Action(element),
  f: fn(element) -> key,
  previous_key: key,
  previous_element: element,
) -> Action(List(element)) {
  case next_chunk(continuation, f, previous_key, [previous_element]) {
    LastBy(chunk) -> Continue(chunk, stop)
    AnotherBy(chunk, key, el, next) ->
      Continue(chunk, fn() { do_chunk(next, f, key, el) })
  }
}

/// Creates an iterator that emits chunks of elements
/// for which `f` returns the same value.
///
/// ## Examples
///
///    > from_list([1, 2, 2, 3, 4, 4, 6, 7, 7]) |> chunk(by: fn(n) { n % 2 }) |> to_list
///    [[1], [2, 2], [3], [4, 4, 6], [7, 7]]
///
pub fn chunk(
  over iterator: Iterator(element),
  by f: fn(element) -> key,
) -> Iterator(List(element)) {
  fn() {
    case iterator.continuation() {
      Stop -> Stop
      Continue(e, next) -> do_chunk(next, f, f(e), e)
    }
  }
  |> Iterator
}

// Result of collecting a single sized chunk
type SizedChunk(element) {
  Another(List(element), fn() -> Action(element))
  Last(List(element))
  NoMore
}

fn next_sized_chunk(
  continuation: fn() -> Action(element),
  left: Int,
  current_chunk: List(element),
) -> SizedChunk(element) {
  case continuation() {
    Stop ->
      case current_chunk {
        [] -> NoMore
        remaining -> Last(list.reverse(remaining))
      }
    Continue(e, next) -> {
      let chunk = [e, ..current_chunk]
      case left > 1 {
        False -> Another(list.reverse(chunk), next)
        True -> next_sized_chunk(next, left - 1, chunk)
      }
    }
  }
}

fn do_sized_chunk(
  continuation: fn() -> Action(element),
  count: Int,
) -> fn() -> Action(List(element)) {
  fn() {
    case next_sized_chunk(continuation, count, []) {
      NoMore -> Stop
      Last(chunk) -> Continue(chunk, stop)
      Another(chunk, next_element) ->
        Continue(chunk, do_sized_chunk(next_element, count))
    }
  }
}

/// Creates an iterator that emits chunks of given size.
///
/// If the last chunk does not have `count` elements, it is yielded
/// as a partial chunk, with less than `count` elements.
///
/// For any `count` less than 1 this function behaves as if it was set to 1.
///
/// ## Examples
///
///    > from_list([1, 2, 3, 4, 5, 6]) |> sized_chunk(into: 2) |> to_list
///    [[1, 2], [3, 4], [5, 6]]
///
///    > from_list([1, 2, 3, 4, 5, 6, 7, 8]) |> sized_chunk(into: 3) |> to_list
///    [[1, 2, 3], [4, 5, 6], [7, 8]]
///
pub fn sized_chunk(
  over iterator: Iterator(element),
  into count: Int,
) -> Iterator(List(element)) {
  iterator.continuation
  |> do_sized_chunk(count)
  |> Iterator
}

fn do_intersperse(
  continuation: fn() -> Action(element),
  separator: element,
) -> Action(element) {
  case continuation() {
    Stop -> Stop
    Continue(e, next) -> {
      let next_interspersed = fn() { do_intersperse(next, separator) }
      Continue(separator, fn() { Continue(e, next_interspersed) })
    }
  }
}

/// Creates an iterator that yields the given element
/// between elements emitted by the underlying iterator.
///
/// ## Examples
///
///    > empty() |> intersperse(with: 0) |> to_list
///    []
///
///    > from_list([1]) |> intersperse(with: 0) |> to_list
///    [1]
///
///    > from_list([1, 2, 3, 4, 5]) |> intersperse(with: 0) |> to_list
///    [1, 0, 2, 0, 3, 0, 4, 0, 5]
///
pub fn intersperse(
  over iterator: Iterator(element),
  with elem: element,
) -> Iterator(element) {
  fn() {
    case iterator.continuation() {
      Stop -> Stop
      Continue(e, next) -> Continue(e, fn() { do_intersperse(next, elem) })
    }
  }
  |> Iterator
}

fn do_any(
  continuation: fn() -> Action(element),
  predicate: fn(element) -> Bool,
) -> Bool {
  case continuation() {
    Stop -> False
    Continue(e, next) -> predicate(e) || do_any(next, predicate)
  }
}

/// Returns `True` if any element emitted by the iterator satisfies the given predicate,
/// `False` otherwise.
///
/// This function short-circuits once it finds a satisfying element.
///
/// An empty iterator results in `False`.
///
/// ## Examples
///
///    > empty() |> any(fn(n) { n % 2 == 0 })
///    False
///
///    > from_list([1, 2, 5, 7, 9]) |> any(fn(n) { n % 2 == 0 })
///    True
///
///    > from_list([1, 3, 5, 7, 9]) |> any(fn(n) { n % 2 == 0 })
///    False
///
pub fn any(
  in iterator: Iterator(element),
  satisfying predicate: fn(element) -> Bool,
) -> Bool {
  iterator.continuation
  |> do_any(predicate)
}

fn do_all(
  continuation: fn() -> Action(element),
  predicate: fn(element) -> Bool,
) -> Bool {
  case continuation() {
    Stop -> True
    Continue(e, next) -> predicate(e) && do_all(next, predicate)
  }
}

/// Returns `True` if all elements emitted by the iterator satisfy the given predicate,
/// `False` otherwise.
///
/// This function short-circuits once it finds a non-satisfying element.
///
/// An empty iterator results in `True`.
///
/// ## Examples
///
///    > empty() |> all(fn(n) { n % 2 == 0 })
///    True
///
///    > from_list([2, 4, 6, 8]) |> all(fn(n) { n % 2 == 0 })
///    True
///
///    > from_list([2, 4, 5, 8]) |> all(fn(n) { n % 2 == 0 })
///    False
///
pub fn all(
  in iterator: Iterator(element),
  satisfying predicate: fn(element) -> Bool,
) -> Bool {
  iterator.continuation
  |> do_all(predicate)
}

if erlang {
  fn update_group_with(
    el: element,
  ) -> fn(Option(List(element))) -> List(element) {
    fn(maybe_group) {
      case maybe_group {
        Some(group) -> [el, ..group]
        None -> [el]
      }
    }
  }

  fn group_updater(
    f: fn(element) -> key,
  ) -> fn(element, Map(key, List(element))) -> Map(key, List(element)) {
    fn(elem, groups) {
      groups
      |> map.update(f(elem), update_group_with(elem))
    }
  }

  /// Returns a `Map(k, List(element))` of elements from the given iterator
  /// grouped with the given key function.
  ///
  /// The order within each group is preserved from the iterator.
  ///
  /// ## Examples
  ///
  ///    > from_list([1, 2, 3, 4, 5, 6]) |> group(by: fn(n) { n % 3 })
  ///    map.from_list([#(0, [3, 6]), #(1, [1, 4]), #(2, [2, 5])])
  ///
  pub fn group(
    in iterator: Iterator(element),
    by key: fn(element) -> key,
  ) -> Map(key, List(element)) {
    iterator
    |> fold(map.new(), group_updater(key))
    |> map.map_values(fn(_, group) { list.reverse(group) })
  }
}

/// This function acts similar to fold, but does not take an initial state.
/// Instead, it starts from the first yielded element
/// and combines it with each subsequent element in turn using the given function.
/// The function is called as f(current_element, accumulator).
///
/// Returns `Ok` to indicate a successful run, and `Error` if called on an empty iterator.
///
/// ## Examples
///
///    > from_list([]) |> reduce(fn(x, y) { x + y })
///    Error(Nil)
///
///    > from_list([1, 2, 3, 4, 5]) |> reduce(fn(x, y) { x + y })
///    Ok(15)
///
pub fn reduce(
  over iterator: Iterator(e),
  with f: fn(e, e) -> e,
) -> Result(e, Nil) {
  case iterator.continuation() {
    Stop -> Error(Nil)
    Continue(e, next) ->
      do_fold(next, f, e)
      |> Ok
  }
}

/// Returns the last element in the given iterator.
///
/// Returns `Error(Nil)` if the iterator is empty.
///
/// This function runs in linear time.
///
/// ## Examples
///
///    > empty() |> last
///    Error(Nil)
///
///    > range(1, 10) |> last
///    Ok(9)
///
pub fn last(iterator: Iterator(element)) -> Result(element, Nil) {
  iterator
  |> reduce(fn(elem, _) { elem })
}

/// Creates an iterator that yields no elements.
///
/// ## Examples
///
///    > empty() |> to_list
///    []
///
pub fn empty() -> Iterator(element) {
  Iterator(stop)
}

/// Creates an iterator that yields exactly one element provided by calling the given function.
///
/// ## Examples
///
///    > once(fn() { 1 }) |> to_list
///    [1]
///
pub fn once(f: fn() -> element) -> Iterator(element) {
  fn() { Continue(f(), stop) }
  |> Iterator
}

/// Creates an iterator that yields the given element exactly once.
///
/// ## Examples
///
///    > single(1) |> to_list
///    [1]
///
pub fn single(elem: element) -> Iterator(element) {
  once(fn() { elem })
}

fn do_interleave(
  current: fn() -> Action(element),
  next: fn() -> Action(element),
) -> Action(element) {
  case current() {
    Stop -> next()
    Continue(e, next_other) ->
      Continue(e, fn() { do_interleave(next, next_other) })
  }
}

/// Creates an iterator that alternates between the two given iterators
/// until both have run out.
///
/// ## Examples
///
///    > from_list([1, 2, 3, 4]) |> interleave(from_list([11, 12, 13, 14])) |> to_list
///    [1, 11, 2, 12, 3, 13, 4, 14]
///
///    > from_list([1, 2, 3, 4]) |> interleave(from_list([100])) |> to_list
///    [1, 100, 2, 3, 4]
///
pub fn interleave(
  left: Iterator(element),
  with right: Iterator(element),
) -> Iterator(element) {
  fn() { do_interleave(left.continuation, right.continuation) }
  |> Iterator
}

fn do_fold_until(
  continuation: fn() -> Action(e),
  f: fn(e, acc) -> list.ContinueOrStop(acc),
  accumulator: acc,
) -> acc {
  case continuation() {
    Stop -> accumulator
    Continue(elem, next) ->
      case f(elem, accumulator) {
        list.Continue(accumulator) -> do_fold_until(next, f, accumulator)
        list.Stop(accumulator) -> accumulator
      }
  }
}

/// Like `fold`, `fold_until` reduces an iterator of elements into a single value by calling a given
/// function on each element in turn, but uses a `list.ContinueOrStop` to determine 
/// whether or not to keep iterating.
///
/// If called on an iterator of infinite length then this function will only ever
/// return if the give function returns list.Stop.
///
///
/// ## Examples
///    > let f = fn(e, acc) {
///    >   case e {
///    >     _ if e < 4 -> list.Continue(e + acc)
///    >     _ -> list.Stop(acc)
///    >   }
///    > }
///    >
///    > [1, 2, 3, 4]
///    > |> from_list
///    > |> iterator.fold_until(from: acc, with: f) 
///    6
///
pub fn fold_until(
  over iterator: Iterator(e),
  from initial: acc,
  with f: fn(e, acc) -> list.ContinueOrStop(acc),
) -> acc {
  iterator.continuation
  |> do_fold_until(f, initial)
}

fn do_try_fold(
  over continuation: fn() -> Action(a),
  with f: fn(a, acc) -> Result(acc, err),
  from accumulator: acc,
) -> Result(acc, err) {
  case continuation() {
    Stop -> Ok(accumulator)
    Continue(elem, next) -> {
      try accumulator = f(elem, accumulator)
      do_try_fold(next, f, accumulator)
    }
  }
}

/// A variant of fold that might fail.
/// 
///
/// The folding function should return `Result(accumulator, error)
/// If the returned value is `Ok(accumulator)` try_fold will try the next value in the iterator.
/// If the returned value is `Error(error)` try_fold will stop and return that error.
///
/// ## Examples
/// 
///    > [1, 2, 3, 4]
///    > |> iterator.from_list()
///    > |> try_fold(0, fn(i, acc) {
///    >   case i < 3 {
///    >     True -> Ok(acc + i)
///    >     False -> Error(Nil)
///    >   }
///    > })
///    Error(Nil)
///
pub fn try_fold(
  over iterator: Iterator(e),
  from initial: acc,
  with f: fn(e, acc) -> Result(acc, err),
) -> Result(acc, err) {
  iterator.continuation
  |> do_try_fold(f, initial)
}
