# Odin syntax overview

This is a practical reference for the parts of Odin needed most often in a small compiler or language tool: declarations, procedures, structures, collections, pointers, expressions, and control flow.

The complete grammar is stored beside this file in [`odin.ebnf`](./odin.ebnf). It was fetched from the official Odin repository:

<https://raw.githubusercontent.com/odin-lang/Odin/master/odin.ebnf>

Examples use the current EBNF notation and assume a source file starts with a package declaration.

## File structure

```odin
package main

import "core:fmt"

main :: proc() {
    fmt.println("Hello, Odin")
}
```

A file consists of:

1. An optional sequence of file tags such as `#+build`.
2. One `package` declaration.
3. Imports and top-level declarations.

Odin inserts semicolons at line endings after identifiers, literals, closing delimiters, `^`, and selected keywords such as `return`, `break`, and `continue`. Semicolons may still be written explicitly when needed, such as between the initializer and condition in a C-style `for` loop.

## Names, literals, and declarations

Identifiers start with a letter or `_` and may contain letters, digits, and `_`.

```odin
count: int = 10          // Explicit type and initializer
limit := 100             // Type inferred from the initializer
width, height := 640, 480
name: string = "Odin"
raw: string = `line 1
line 2`
hex_value := 0xFF
binary_value := 0b1010
ratio := 3.14
```

Odin uses `:` for a typed declaration and `:=` for a declaration with inferred type. Multiple names and values can be declared together.

```odin
uninitialized: int = ---
answer :: 42             // Constant declaration
```

The `::` form is also commonly used to give a procedure a package-level name:

```odin
square :: proc(x: int) -> int {
    return x * x
}
```

Assignments update existing values and support compound operators:

```odin
count = count + 1
count += 1
count *= 2
left, right = right, left
```

## Procedures: definitions and calls

Procedures are Odin's functions. A procedure literal has the form `proc(parameters) -> results { body }`, and a named procedure is normally declared with `::`.

```odin
add :: proc(a, b: int) -> int {
    return a + b
}

result := add(2, 3)
```

Parameters with the same type can be grouped. Results can be a single type or a parenthesized field list.

```odin
divide :: proc(numerator, denominator: f64) -> (quotient: f64, remainder: f64) {
    return numerator / denominator, numerator %% denominator
}

q, r := divide(10, 3)
```

Arguments may be passed positionally or by name:

```odin
configure :: proc(width: int, height: int, title: string = "Window") {
    // configure the window
}

configure(800, 600)
configure(width = 1024, height = 768, title = "Editor")
```

A procedure can mutate caller-owned data by receiving a pointer:

```odin
increment :: proc(value: ^int) {
    value^ += 1
}

number := 41
increment(&number)
// number == 42
```

## Structures and data manipulation

Define a structure with `struct` and named fields. A trailing comma is allowed in field lists and compound literals.

```odin
Point :: struct {
    x, y: f32,
}

Rectangle :: struct {
    origin: Point,
    size:   Point,
}
```

Construct values with a compound literal. Fields can be positional or named.

```odin
origin := Point{0, 0}
box := Rectangle{
    origin = origin,
    size = Point{640, 480},
}
```

Read and update fields with the selector operator `.`. Selectors can be chained through nested structures.

```odin
box.size.x = 800
box.size.y += 40
area := box.size.x * box.size.y
```

A structure can contain arrays, slices, maps, or pointers to other structures:

```odin
Node :: struct {
    value: int,
    next:  ^Node,
}

Inventory :: struct {
    name:  string,
    items: [dynamic]string,
    tags:  map[string]string,
}

inventory := Inventory{
    name = "tools",
    items = {"hammer", "saw"},
    tags = {"owner" = "workshop"},
}
inventory.items[0] = "mallet"
inventory.tags["state"] = "ready"
```

## Arrays, slices, and dynamic arrays

An array type has a fixed length. A slice is a view over contiguous elements. A dynamic array owns a resizable sequence.

```odin
fixed: [3]int = {10, 20, 30}
inferred := [?]int{1, 2, 3, 4}
view: []int = fixed[:]
values: [dynamic]int = {5, 6, 7}
```

Index arrays and slices with `[]`; bounds use a half-open range with `..<` or an inclusive range with `..=` where a range expression is accepted.

```odin
first := fixed[0]
fixed[1] = 25
middle := fixed[1:3]
all := fixed[:]
```

Dynamic arrays can be extended through the built-in `append` procedure. Passing the address lets it update the dynamic-array header.

```odin
append(&values, 8, 9)
for value in values {
    fmt.println(value)
}
```

Use a range loop when both the index and element are needed:

```odin
for value, index in values {
    values[index] = value * 2
}
```

An array or slice can be passed to a procedure by its slice type when the procedure should operate on a sequence without taking ownership:

```odin
sum :: proc(values: []int) -> int {
    total := 0
    for value in values {
        total += value
    }
    return total
}

total := sum(fixed[:])
```

## Pointers

The pointer type `^T` refers to a value of type `T`. The unary `&` operator takes an address, and the postfix `^` operator dereferences a pointer.

```odin
value := 10
pointer: ^int = &value
pointer^ = 20
fmt.println(value) // 20
```

Pointers are useful for in-place mutation and for linked data:

```odin
Point :: struct {
    x, y: int,
}

move :: proc(point: ^Point, dx, dy: int) {
    point^.x += dx
    point^.y += dy
}

point := Point{10, 20}
move(&point, 3, -2)
```

A pointer field can be nil when it has not been assigned a value. Check it before dereferencing when the value may be absent:

```odin
node := Node{value = 1}
if node.next != nil {
    node.next^.value += 1
}
```

The grammar also supports multi-pointer types such as `[^]T` when multiple levels of indirection are required.

## Operators and expressions

Odin's binary-expression precedence runs from lower to higher precedence as follows:

| Group | Operators |
| --- | --- |
| Fallback | `or_else` |
| Conditional/range | `? :`, `if ... else`, `when ... else`, `..<`, `..=` |
| Logical OR | `\|\|` |
| Logical AND | `&&` |
| Comparison | `==`, `!=`, `<`, `<=`, `>`, `>=` |
| Additive | `+`, `-`, `\|`, `~`, `in`, `not_in` |
| Multiplicative | `*`, `/`, `%`, `%%`, `&`, `&~`, `<<`, `>>` |

Unary operators include `+`, `-`, `~`, `&`, and `!`.

```odin
sum := a + b
scaled := sum * 2
remainder := sum % 3
is_large := sum >= 100
in_range := value >= 0 && value < limit
has_flag := flags & mask != 0
shifted := bits << 2
negated := !enabled
```

Assignment operators include `=`, `+=`, `-=`, `*=`, `/=`, `%=`, `%%=`, `|=`, `~=`, `&=`, `&~=`, `<<=`, `>>=`, `&&=`, and `||=`.

Function calls, field access, indexing, slicing, and dereferencing can be chained:

```odin
length := inventory.items[0].len
next_value := node.next^.value
```

## Basic statements

### `if`

An `if` condition is followed by a block. An initializer can appear before a semicolon.

```odin
if value, ok := lookup(key); ok {
    fmt.println(value)
} else {
    fmt.println("missing")
}
```

### `for`

A condition-only loop, C-style loop, and range loop are all supported.

```odin
for running {
    update()
}

for i := 0; i < 10; i += 1 {
    process(i)
}

for item, index in items {
    fmt.println(index, item)
}
```

### `switch`

A switch selects a case based on an expression. Case bodies do not require an explicit `break`.

```odin
switch command {
case .Start:
    start()
case .Stop:
    stop()
case:
    report_unknown(command)
}
```

### `when`

`when` is a compile-time conditional form with the same general block shape as `if`.

```odin
when debug_build {
    fmt.println("debug build")
} else {
    fmt.println("optimized build")
}
```

### `return`, `defer`, and branches

```odin
read_file :: proc(path: string) -> (data: []u8, ok: bool) {
    file := open(path)
    defer close(file)

    data, ok = read_all(file)
    return data, ok
}

for {
    if done() {
        break
    }
    if should_skip() {
        continue
    }
    work()
}
```

`defer` schedules a statement or block for execution when the surrounding procedure exits. `break`, `continue`, and `fallthrough` control loops and switch cases.

## Quick reference

```odin
// Declaration
name: Type = value
name := value
constant :: value

// Procedure
name :: proc(arg: Type) -> ReturnType {
    return expression
}

// Struct
Type :: struct {
    field: FieldType,
}
value := Type{field = expression}

// Collections
array: [N]Type = {}
slice: []Type = array[:]
dynamic: [dynamic]Type = {}
append(&dynamic, value)

// Pointers
pointer: ^Type = &value
value = pointer^

// Mutation
value.field += 1
array[index] = value
```
