// EXPECTED DIAGNOSTIC: invalid pointer operation, cannot dereference `value` of non-pointer type int (line 9)
// Reference compiler: "Cannot dereference 'value' of type 'int'"
package main

import "core:fmt"

main :: proc() {
	value := 10
	fmt.println(value^)
}
