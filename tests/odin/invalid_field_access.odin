// EXPECTED DIAGNOSTIC: invalid field access, `p` of type `Point` has no field `z` (line 13)
// Reference compiler: "'p' of type 'Point' has no field 'z'"
package main

import "core:fmt"

Point :: struct {
	x, y: int,
}

main :: proc() {
	p := Point{1, 2}
	fmt.println(p.z)
}
