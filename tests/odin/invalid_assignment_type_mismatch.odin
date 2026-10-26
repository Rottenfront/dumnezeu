// EXPECTED DIAGNOSTIC: incompatible assignment, a string cannot be assigned to `count` of type int (line 9)
// Reference compiler: "Cannot convert '"ten"' to 'int' from 'untyped string'"
package main

import "core:fmt"

main :: proc() {
	count: int = 10
	count = "ten"
	fmt.println(count)
}
