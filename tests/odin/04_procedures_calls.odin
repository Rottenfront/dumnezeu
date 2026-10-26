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

add :: proc(a, b: int) -> int {
	return a + b
}

square :: proc(x: int) -> int {
	return x * x
}

divide :: proc(numerator, denominator: f64) -> (quotient: f64, ok: bool) {
	if denominator == 0 {
		return 0, false
	}
	return numerator / denominator, true
}

min_max :: proc(a, b: int) -> (lo: int, hi: int) {
	if a < b {
		lo, hi = a, b
	} else {
		lo, hi = b, a
	}
	return
}

configure :: proc(width: int, height: int, title: string = "Window") -> string {
	return fmt.tprintf("%s:%dx%d", title, width, height)
}

sum_all :: proc(values: ..int) -> int {
	total := 0
	for v in values {
		total += v
	}
	return total
}

apply :: proc(f: proc(int) -> int, value: int) -> int {
	return f(value)
}

increment :: proc(value: ^int) {
	value^ += 1
}

main :: proc() {
	failures := 0

	check("simple call", add(2, 3) == 5, &failures)
	check("nested calls", add(square(3), square(4)) == 25, &failures)

	q, ok := divide(10, 4)
	check("multiple results", ok && q == 2.5, &failures)
	_, ok = divide(1, 0)
	check("failure result", !ok, &failures)

	lo, hi := min_max(9, 4)
	check("named results", lo == 4 && hi == 9, &failures)

	check("default argument", configure(800, 600) == "Window:800x600", &failures)
	check(
		"named arguments",
		configure(width = 1024, height = 768, title = "Editor") == "Editor:1024x768",
		&failures,
	)

	check("variadic empty", sum_all() == 0, &failures)
	check("variadic values", sum_all(1, 2, 3, 4) == 10, &failures)

	numbers := []int{5, 6, 7}
	check("variadic spread", sum_all(..numbers) == 18, &failures)

	check("procedure value", apply(square, 7) == 49, &failures)

	double := proc(x: int) -> int {
		return x * 2
	}
	check("procedure literal", apply(double, 21) == 42, &failures)

	counter := 41
	increment(&counter)
	check("pointer parameter", counter == 42, &failures)

	if failures > 0 {
		fmt.printfln("%d check(s) failed", failures)
		os.exit(1)
	}
	fmt.println("All checks passed")
}
