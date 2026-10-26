#+feature dynamic-literals
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

collect_squares :: proc(count: int) -> [dynamic]int {
	result: [dynamic]int
	for i in 1 ..= count {
		append(&result, i * i)
	}
	return result
}

main :: proc() {
	failures := 0

	values: [dynamic]int
	defer delete(values)
	check("starts empty", len(values) == 0, &failures)

	append(&values, 5)
	append(&values, 6, 7)
	check("append", len(values) == 3 && values[0] == 5 && values[2] == 7, &failures)

	values[1] = 60
	check("index write", values[1] == 60, &failures)

	for &value in values {
		value += 1
	}
	check("mutate by reference", values[0] == 6 && values[1] == 61 && values[2] == 8, &failures)

	total := 0
	for value, index in values {
		total += value * (index + 1)
	}
	check("iterate with index", total == 6 + 122 + 24, &failures)

	popped := pop(&values)
	check("pop", popped == 8 && len(values) == 2, &failures)

	ordered_remove(&values, 0)
	check("ordered remove", len(values) == 1 && values[0] == 61, &failures)

	clear(&values)
	check("clear", len(values) == 0, &failures)

	reserved := make([dynamic]int, 0, 16)
	defer delete(reserved)
	check("reserved capacity", len(reserved) == 0 && cap(reserved) >= 16, &failures)

	squares := collect_squares(5)
	defer delete(squares)
	check("returned dynamic array", len(squares) == 5 && squares[4] == 25, &failures)

	view := squares[1:4]
	check("slice of dynamic array", len(view) == 3 && view[0] == 4 && view[2] == 16, &failures)

	words: [dynamic]string
	defer delete(words)
	append(&words, "alpha", "beta")
	append(&words, "gamma")
	check("dynamic strings", len(words) == 3 && words[1] == "beta", &failures)

	initial: [dynamic]int = {3, 2, 1}
	defer delete(initial)
	check("literal initialization", len(initial) == 3 && initial[0] == 3, &failures)

	if failures > 0 {
		fmt.printfln("%d check(s) failed", failures)
		os.exit(1)
	}
	fmt.println("All checks passed")
}
