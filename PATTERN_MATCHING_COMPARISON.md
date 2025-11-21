# Pattern Matching: Elixir vs Python

## Overview

Pattern matching is a fundamental feature in functional programming that allows you to destructure data and match against patterns. Elixir has **first-class, powerful pattern matching** built into the language core, while Python has **limited pattern matching** introduced in Python 3.10+ with the `match` statement, plus some destructuring features.

---

## 1. Basic Concepts

### Elixir
In Elixir, the `=` operator is the **match operator**, not just assignment. It attempts to make the left side match the right side.

```elixir
# Simple assignment (actually pattern matching)
x = 1  # x matches 1

# Pattern matching with tuples
{a, b, c} = {1, 2, 3}
# a = 1, b = 2, c = 3

# This will raise a MatchError
{a, b} = {1, 2, 3}  # ❌ Error: right side has 3 elements, left has 2
```

### Python
Python has **destructuring** (unpacking) but true pattern matching only arrived in Python 3.10 with `match/case`.

```python
# Tuple unpacking (similar to pattern matching)
a, b, c = (1, 2, 3)
# a = 1, b = 2, c = 3

# This raises ValueError
a, b = (1, 2, 3)  # ❌ ValueError: too many values to unpack

# Pattern matching (Python 3.10+)
match value:
    case 1:
        print("one")
    case 2:
        print("two")
```

---

## 2. Pattern Matching in Function Definitions

### Elixir
Functions can have multiple clauses that pattern match on arguments:

```elixir
defmodule Math do
  # Pattern match on specific values
  def factorial(0), do: 1
  def factorial(1), do: 1
  def factorial(n) when n > 1 do
    n * factorial(n - 1)
  end

  # Pattern match on data structures
  def describe([]), do: "empty list"
  def describe([head | tail]), do: "list with head #{head}"

  # Pattern match on maps
  def greet(%{name: name, age: age}) do
    "Hello #{name}, you are #{age} years old"
  end

  # Multiple function heads for different tuple patterns
  def process({:ok, value}), do: "Success: #{value}"
  def process({:error, reason}), do: "Error: #{reason}"
end

Math.factorial(5)  # 120
Math.describe([1, 2, 3])  # "list with head 1"
Math.greet(%{name: "Alice", age: 30})  # "Hello Alice, you are 30 years old"
Math.process({:ok, "data"})  # "Success: data"
```

### Python
Python cannot pattern match in function signatures. You need if/elif or match statements inside:

```python
# Cannot do this in Python - no pattern matching in function definitions
# You must use conditionals inside the function

def factorial(n):
    if n == 0 or n == 1:
        return 1
    elif n > 1:
        return n * factorial(n - 1)

def describe(lst):
    if not lst:
        return "empty list"
    else:
        return f"list with head {lst[0]}"

def greet(person):
    # Dictionary unpacking
    name = person.get("name")
    age = person.get("age")
    return f"Hello {name}, you are {age} years old"

# Python 3.10+ match statement
def process(result):
    match result:
        case ("ok", value):
            return f"Success: {value}"
        case ("error", reason):
            return f"Error: {reason}"
        case _:
            return "Unknown result"

factorial(5)  # 120
describe([1, 2, 3])  # "list with head 1"
greet({"name": "Alice", "age": 30})  # "Hello Alice, you are 30 years old"
process(("ok", "data"))  # "Success: data"
```

---

## 3. List/Tuple Destructuring

### Elixir

```elixir
# Head and tail pattern
[first, second | rest] = [1, 2, 3, 4, 5]
# first = 1, second = 2, rest = [3, 4, 5]

# Ignore values with underscore
[head | _tail] = [1, 2, 3]
# head = 1, _tail is ignored

# Match specific patterns
[1, 2, third] = [1, 2, 3]
# third = 3 (1 and 2 must match exactly)

# Nested patterns
[{:ok, value} | rest] = [{:ok, 42}, {:error, "bad"}]
# value = 42, rest = [{:error, "bad"}]
```

### Python

```python
# Basic unpacking
first, second, *rest = [1, 2, 3, 4, 5]
# first = 1, second = 2, rest = [3, 4, 5]

# Ignore values with underscore (convention, not enforced)
head, *_ = [1, 2, 3]
# head = 1

# Cannot force specific values in unpacking (must check after)
a, b, third = [1, 2, 3]
# third = 3, but no validation that a==1 and b==2

# Python 3.10+ match for nested patterns
match data:
    case [("ok", value), *rest]:
        print(f"First is ok with {value}")
```

---

## 4. Map/Dictionary Pattern Matching

### Elixir

```elixir
# Match specific keys
%{name: name} = %{name: "Alice", age: 30, city: "NYC"}
# name = "Alice" (age and city are ignored)

# Match multiple keys
%{name: n, age: a} = %{name: "Bob", age: 25}
# n = "Bob", a = 25

# Match with literals (must match exactly)
%{status: :ok, value: val} = %{status: :ok, value: 42}
# val = 42 (status must be :ok or MatchError)

# Pattern matching in case
case user do
  %{role: :admin, name: name} ->
    "Admin: #{name}"
  %{role: :user, name: name} ->
    "User: #{name}"
  _ ->
    "Unknown"
end
```

### Python

```python
# Dictionary unpacking (no pattern matching)
person = {"name": "Alice", "age": 30, "city": "NYC"}
name = person["name"]  # Must access explicitly

# Or use get with defaults
name = person.get("name")

# Python 3.10+ match for dictionaries
match user:
    case {"role": "admin", "name": name}:
        print(f"Admin: {name}")
    case {"role": "user", "name": name}:
        print(f"User: {name}")
    case _:
        print("Unknown")

# Note: In Python match, extra keys are allowed (unlike Elixir which can be strict)
```

---

## 5. Pin Operator (Elixir-specific)

### Elixir

The pin operator `^` allows you to match against an existing variable's value rather than rebinding:

```elixir
x = 1

# Without pin - rebinds x
x = 2  # x is now 2

# With pin - matches against existing value
x = 1
^x = 1  # OK - matches
^x = 2  # MatchError - 1 doesn't match 2

# Useful in function clauses
def contains?(list, ^value) do
  value in list
end

# Pattern matching in case with pin
expected = :ok
case result do
  {^expected, data} -> "Got expected status with #{data}"
  _ -> "Unexpected"
end
```

### Python

Python has no equivalent to the pin operator. Variables in patterns always bind/assign:

```python
x = 1
x = 2  # Always rebinds, no way to "match against x"

# Must use conditionals to check values
expected = "ok"
if result[0] == expected:
    print(f"Got expected status with {result[1]}")
```

---

## 6. Guards (Elixir-specific)

### Elixir

Guards allow additional constraints on patterns:

```elixir
defmodule Number do
  def classify(n) when n < 0, do: :negative
  def classify(0), do: :zero
  def classify(n) when n > 0, do: :positive

  # Complex guards
  def safe_div(a, b) when b != 0 do
    a / b
  end
  def safe_div(_a, 0), do: {:error, :division_by_zero}

  # Guards in case
  case age do
    a when a < 13 -> :child
    a when a < 20 -> :teenager
    a when a < 60 -> :adult
    _ -> :senior
  end
end
```

### Python

No guards in Python. Must use if/elif inside functions:

```python
def classify(n):
    if n < 0:
        return "negative"
    elif n == 0:
        return "zero"
    else:
        return "positive"

def safe_div(a, b):
    if b != 0:
        return a / b
    else:
        return ("error", "division_by_zero")

# Python 3.10+ match with guards
match age:
    case a if a < 13:
        return "child"
    case a if a < 20:
        return "teenager"
    case a if a < 60:
        return "adult"
    case _:
        return "senior"
```

---

## 7. Practical Examples Side-by-Side

### Example 1: Parsing HTTP Responses

**Elixir:**
```elixir
case HTTPoison.get(url) do
  {:ok, %{status_code: 200, body: body}} ->
    {:ok, decode_json(body)}

  {:ok, %{status_code: 404}} ->
    {:error, :not_found}

  {:ok, %{status_code: status}} when status >= 500 ->
    {:error, :server_error}

  {:error, %{reason: reason}} ->
    {:error, reason}
end
```

**Python:**
```python
response = requests.get(url)

if response.status_code == 200:
    return ("ok", json.loads(response.text))
elif response.status_code == 404:
    return ("error", "not_found")
elif response.status_code >= 500:
    return ("error", "server_error")
else:
    return ("error", "unknown")
```

### Example 2: Processing Nested Data

**Elixir:**
```elixir
def process_order(%{items: [%{name: name, price: price} | _rest], status: :pending}) do
  "First item: #{name} at $#{price}, order is pending"
end

def process_order(%{items: [], status: _}) do
  "Empty order"
end

def process_order(%{status: :shipped}) do
  "Order already shipped"
end
```

**Python (3.10+):**
```python
def process_order(order):
    match order:
        case {"items": [{"name": name, "price": price}, *_], "status": "pending"}:
            return f"First item: {name} at ${price}, order is pending"
        case {"items": [], "status": _}:
            return "Empty order"
        case {"status": "shipped"}:
            return "Order already shipped"
```

### Example 3: Recursive List Processing

**Elixir:**
```elixir
defmodule ListOps do
  def sum([]), do: 0
  def sum([head | tail]), do: head + sum(tail)

  def map([], _func), do: []
  def map([head | tail], func) do
    [func.(head) | map(tail, func)]
  end

  def filter([], _pred), do: []
  def filter([head | tail], pred) do
    if pred.(head) do
      [head | filter(tail, pred)]
    else
      filter(tail, pred)
    end
  end
end

ListOps.sum([1, 2, 3, 4, 5])  # 15
ListOps.map([1, 2, 3], &(&1 * 2))  # [2, 4, 6]
ListOps.filter([1, 2, 3, 4], &(&1 > 2))  # [3, 4]
```

**Python:**
```python
def sum_list(lst):
    if not lst:
        return 0
    else:
        return lst[0] + sum_list(lst[1:])

def map_list(lst, func):
    if not lst:
        return []
    else:
        return [func(lst[0])] + map_list(lst[1:], func)

def filter_list(lst, pred):
    if not lst:
        return []
    elif pred(lst[0]):
        return [lst[0]] + filter_list(lst[1:], pred)
    else:
        return filter_list(lst[1:], pred)

sum_list([1, 2, 3, 4, 5])  # 15
map_list([1, 2, 3], lambda x: x * 2)  # [2, 4, 6]
filter_list([1, 2, 3, 4], lambda x: x > 2)  # [3, 4]
```

---

## 8. Key Differences Summary

| Feature | Elixir | Python |
|---------|--------|--------|
| **Pattern matching operator** | `=` (match operator) | No dedicated operator |
| **Function clause matching** | ✅ Multiple function heads | ❌ Must use if/elif inside |
| **Guards** | ✅ `when` clauses | ⚠️ Only in `match` with `if` |
| **Pin operator** | ✅ `^var` to match value | ❌ Not available |
| **Match statement** | `case` (since v1.0) | `match/case` (since 3.10) |
| **List head\|tail** | ✅ `[h \| t]` native syntax | ⚠️ `[h, *t]` unpacking only |
| **Map matching** | ✅ Powerful, validates structure | ⚠️ Basic in `match` statement |
| **Compile-time checks** | ✅ Warns on impossible patterns | ⚠️ Limited |
| **Exhaustiveness checking** | ⚠️ Runtime warnings | ❌ No checking |
| **Performance** | Optimized at compile-time | Interpreted at runtime |

---

## 9. When to Use Pattern Matching

### Best Use Cases in Elixir:
1. **Parsing structured data** (JSON, API responses, messages)
2. **Control flow** based on data shape
3. **Recursive algorithms** (especially on lists)
4. **State machines** with multiple states
5. **Error handling** with `{:ok, value}` / `{:error, reason}` tuples

### Best Use Cases in Python:
1. **Structural destructuring** (unpacking tuples, lists)
2. **Type-based dispatch** (Python 3.10+ match)
3. **Simple case analysis** (replacing long if/elif chains)
4. **Data validation** patterns

---

## 10. Conclusion

**Elixir** treats pattern matching as a first-class citizen:
- It's pervasive throughout the language
- Used in variable binding, function definitions, case statements, with clauses
- Optimized at compile-time
- Encourages declarative, functional style

**Python** has added pattern matching as a feature:
- Available via `match` statement (3.10+)
- Limited compared to functional languages
- Destructuring/unpacking predates true pattern matching
- More imperative style with if/elif remains common

For functional programming with heavy pattern matching, **Elixir wins hands down**. For Python developers, the new `match` statement is a welcome addition but doesn't fundamentally change how Python code is written.
