// EXPECTED DIAGNOSTIC: undeclared name `missing_value` (line 9)
// Reference compiler: "Undeclared name: missing_value"
package main

import "core:fmt"

main :: proc() {
	total := 1
	total += missing_value
	fmt.println(total)
}
