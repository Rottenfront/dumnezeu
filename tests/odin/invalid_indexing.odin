// EXPECTED DIAGNOSTIC (line 11): invalid indexing, `scalar` of type int cannot be indexed
// EXPECTED DIAGNOSTIC (line 14): invalid indexing, constant index 5 is out of bounds for [3]int (valid range 0..<3)
// Reference compiler: "Cannot index 'scalar' of type 'int'"
//                     "Index '5' is out of bounds range 0..<3, got 5"
package main

import "core:fmt"

main :: proc() {
	scalar := 42
	fmt.println(scalar[0])

	values := [3]int{1, 2, 3}
	fmt.println(values[5])
}
