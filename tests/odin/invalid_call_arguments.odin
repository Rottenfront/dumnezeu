// EXPECTED DIAGNOSTIC (line 14): invalid call to `add`, too many arguments (expected 2, got 3)
// EXPECTED DIAGNOSTIC (line 15): invalid call to `add`, argument type mismatch (string given for int parameter)
// Reference compiler: "Too many arguments for 'add', expected 2 arguments, got 3"
//                     "Cannot convert '"two"' to 'int' from 'untyped string'"
package main

import "core:fmt"

add :: proc(a, b: int) -> int {
	return a + b
}

main :: proc() {
	fmt.println(add(1, 2, 3))
	fmt.println(add(1, "two"))
}
