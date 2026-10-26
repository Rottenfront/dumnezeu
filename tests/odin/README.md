# Odin source fixtures

Standalone Odin programs (`package main`, one file each) for exercising a future Odin parser and semantic checker. They are source fixtures only: no runner in this repository consumes them yet. Until an Odin parser runner exists, nothing under `tests/odin/` is wired into Cabal or executed automatically.

The syntax follows `resources/odin.ebnf` and `resources/syntax-overview.md`.

## Valid programs

Files named `NN_description.odin` are valid programs. The numeric prefix gives the intended order, from simplest to most complex, so a parser or checker can be brought up one language feature at a time.

| File | Covers |
| --- | --- |
| `01_declarations_operators.odin` | `:`, `:=`, `::`, literals, arithmetic, comparison, logical, bitwise, shift, `cast` |
| `02_assignments.odin` | `=`, every compound assignment operator, tuple assignment and swaps |
| `03_conditionals_loops.odin` | `if`/`else if`, init statements, `switch`, C-style / condition / range / infinite `for`, `break`, `continue`, labels |
| `04_procedures_calls.odin` | parameters, multiple and named results, default and named arguments, variadics, procedure values and literals |
| `05_fibonacci_recursive.odin` | recursive `fib` and `factorial` |
| `06_structs_mutation.odin` | struct declaration, compound literals, nested fields, copy vs. pointer mutation |
| `07_arrays_slices.odin` | fixed arrays, `[?]T`, slicing, slice aliasing, nested arrays |
| `08_dynamic_arrays.odin` | `[dynamic]T`, `append`, `pop`, `ordered_remove`, `clear`, `make`, `delete`, `defer`, `for &v in` |
| `09_pointers.odin` | `^T`, `&`, `^` dereference, nil, pointer parameters, linked nodes, `new`/`free` |
| `10_fibonacci_iterative.odin` | iterative `fib`, cross-check against recursion, sequence building |
| `11_nested_data_processing.odin` | structs containing dynamic arrays of structs, enums, enumerated arrays, aggregation and in-place updates |

Expected behavior: each program imports `core:fmt` and reports its own result. Every check prints `PASS <label>` or `FAIL <label>`, and the program ends with `All checks passed` and exit code 0. If any check fails, it prints the failure count and exits with code 1 via `core:os`. A conforming front end must accept all of these files without diagnostics.

## Invalid programs

Files named `invalid_<problem>.odin` are intentionally ill-formed. They are syntactically valid Odin that should parse, but must be rejected by semantic checking. They are not numbered because they are independent of each other.

| File | Expected rejection |
| --- | --- |
| `invalid_undefined_identifier.odin` | use of an undeclared name |
| `invalid_assignment_type_mismatch.odin` | assigning a string to an `int` variable |
| `invalid_call_arguments.odin` | wrong argument count and wrong argument type in a call |
| `invalid_field_access.odin` | selecting a field that the struct does not have |
| `invalid_indexing.odin` | indexing a non-indexable value, and a constant out-of-bounds index |
| `invalid_pointer_operation.odin` | dereferencing a non-pointer value |

Each invalid file begins with one or more `// EXPECTED DIAGNOSTIC` comments describing the error and the line it is reported on. Where the reference Odin compiler's wording is useful, it is quoted on a following `// Reference compiler:` line. A checker is not required to reproduce that wording exactly, but it must report an error of the described kind at the described line, and must not report the file as valid. If a fixture is edited, keep the line numbers in the comments in sync.

## Validating with the Odin compiler

If an `odin` toolchain is installed, the fixtures can be cross-checked against the reference compiler:

```sh
# valid: build and run, expect exit code 0 and no FAIL lines
odin run tests/odin/05_fibonacci_recursive.odin -file

# valid: type-check only
odin check tests/odin/05_fibonacci_recursive.odin -file

# invalid: expect a non-zero exit code and the diagnostic named in the file
odin check tests/odin/invalid_field_access.odin -file
```

Always pass `-file`. The files all define `main` in `package main`, so the directory cannot be compiled as a single package.
