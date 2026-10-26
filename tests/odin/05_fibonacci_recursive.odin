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

fib :: proc(n: int) -> int {
	if n < 2 {
		return n
	}
	return fib(n - 1) + fib(n - 2)
}

factorial :: proc(n: int) -> int {
	if n <= 1 {
		return 1
	}
	return n * factorial(n - 1)
}

main :: proc() {
	failures := 0

	expected := [?]int{0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377}

	for want, n in expected {
		got := fib(n)
		fmt.printfln("fib(%d) = %d", n, got)
		check(fmt.tprintf("fib(%d)", n), got == want, &failures)
	}

	check("fib(20)", fib(20) == 6765, &failures)
	check("fib recurrence", fib(15) == fib(14) + fib(13), &failures)
	check("factorial(5)", factorial(5) == 120, &failures)
	check("factorial(10)", factorial(10) == 3628800, &failures)

	if failures > 0 {
		fmt.printfln("%d check(s) failed", failures)
		os.exit(1)
	}
	fmt.println("All checks passed")
}
