package main

import "core:fmt"
import "core:os"

check :: proc(label: string, ok: bool, failures: ^int) {
	if ok {
		fmt.printfln("PASS %s", label)
	} else {
		fmt.printfln("FAIL %s", label)
		failures^ += 1
	}
}

main :: proc() {
	failures := 0

	n := 5
	n = n + 1
	check("simple assignment", n == 6, &failures)

	n += 4
	check("add assign", n == 10, &failures)
	n -= 3
	check("sub assign", n == 7, &failures)
	n *= 6
	check("mul assign", n == 42, &failures)
	n /= 5
	check("div assign", n == 8, &failures)
	n %= 5
	check("mod assign", n == 3, &failures)

	bits := 0b1100
	bits &= 0b0110
	check("and assign", bits == 0b0100, &failures)
	bits |= 0b0011
	check("or assign", bits == 0b0111, &failures)
	bits ~= 0b0101
	check("xor assign", bits == 0b0010, &failures)
	bits <<= 3
	check("shl assign", bits == 0b10000, &failures)
	bits >>= 2
	check("shr assign", bits == 0b100, &failures)
	bits &~= 0b100
	check("and-not assign", bits == 0, &failures)

	ready := true
	ready &&= false
	check("logical and assign", !ready, &failures)
	ready ||= true
	check("logical or assign", ready, &failures)

	left, right := 1, 2
	left, right = right, left
	check("swap via tuple assignment", left == 2 && right == 1, &failures)

	a, b, c := 1, 2, 3
	a, b, c = c, a, b
	check("rotate three values", a == 3 && b == 1 && c == 2, &failures)

	text := "hello"
	text = "world"
	check("string reassignment", text == "world", &failures)

	ratio := 1.5
	ratio *= 2
	check("float compound assign", ratio == 3.0, &failures)

	if failures > 0 {
		fmt.printfln("%d check(s) failed", failures)
		os.exit(1)
	}
	fmt.println("All checks passed")
}
