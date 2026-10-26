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

fib_recursive :: proc(n: int) -> int {
	if n < 2 {
		return n
	}
	return fib_recursive(n - 1) + fib_recursive(n - 2)
}

fib_iterative :: proc(n: int) -> int {
	if n < 2 {
		return n
	}
	previous, current := 0, 1
	for _ in 2 ..= n {
		previous, current = current, previous + current
	}
	return current
}

fib_sequence :: proc(count: int) -> [dynamic]int {
	sequence: [dynamic]int
	for i in 0 ..< count {
		append(&sequence, fib_iterative(i))
	}
	return sequence
}

fib_table :: proc(table: []int) {
	for i in 0 ..< len(table) {
		if i < 2 {
			table[i] = i
		} else {
			table[i] = table[i - 1] + table[i - 2]
		}
	}
}

main :: proc() {
	failures := 0

	known := [?]int{0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55}
	for want, n in known {
		check(fmt.tprintf("fib_iterative(%d)", n), fib_iterative(n) == want, &failures)
	}

	check("fib_iterative(50)", fib_iterative(50) == 12586269025, &failures)
	check("fib_iterative(90)", fib_iterative(90) == 2880067194370816120, &failures)

	agree := true
	for n in 0 ..= 20 {
		if fib_iterative(n) != fib_recursive(n) {
			agree = false
		}
	}
	check("iterative matches recursive for 0..=20", agree, &failures)

	sequence := fib_sequence(10)
	defer delete(sequence)
	fmt.println("sequence:", sequence[:])
	check("sequence length", len(sequence) == 10, &failures)
	check("sequence last", sequence[9] == 34, &failures)

	table: [15]int
	fib_table(table[:])
	check("table fill", table[14] == 377 && table[7] == 13, &failures)

	if failures > 0 {
		fmt.printfln("%d check(s) failed", failures)
		os.exit(1)
	}
	fmt.println("All checks passed")
}
