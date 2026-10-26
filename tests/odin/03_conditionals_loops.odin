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

Color :: enum {
	Red,
	Green,
	Blue,
}

classify :: proc(n: int) -> string {
	if n < 0 {
		return "negative"
	} else if n == 0 {
		return "zero"
	} else {
		return "positive"
	}
}

color_code :: proc(c: Color) -> int {
	switch c {
	case .Red:
		return 1
	case .Green:
		return 2
	case .Blue:
		return 3
	}
	return 0
}

main :: proc() {
	failures := 0

	check("if negative", classify(-5) == "negative", &failures)
	check("if zero", classify(0) == "zero", &failures)
	check("if positive", classify(9) == "positive", &failures)

	if doubled := 21 * 2; doubled == 42 {
		check("if with init statement", true, &failures)
	} else {
		check("if with init statement", false, &failures)
	}

	check("switch red", color_code(.Red) == 1, &failures)
	check("switch green", color_code(.Green) == 2, &failures)
	check("switch last case", color_code(.Blue) == 3, &failures)

	total := 0
	for i := 1; i <= 10; i += 1 {
		total += i
	}
	check("c-style for", total == 55, &failures)

	countdown := 5
	steps := 0
	for countdown > 0 {
		countdown -= 1
		steps += 1
	}
	check("condition-only for", steps == 5 && countdown == 0, &failures)

	exclusive := 0
	for i in 0 ..< 5 {
		exclusive += i
	}
	check("half-open range", exclusive == 10, &failures)

	inclusive := 0
	for i in 1 ..= 5 {
		inclusive += i
	}
	check("inclusive range", inclusive == 15, &failures)

	evens := 0
	for i in 0 ..< 20 {
		if i % 2 != 0 {
			continue
		}
		if i > 10 {
			break
		}
		evens += 1
	}
	check("continue and break", evens == 6, &failures)

	pairs := 0
	outer: for i in 0 ..< 5 {
		for j in 0 ..< 5 {
			if j > i {
				continue outer
			}
			if i == 4 {
				break outer
			}
			pairs += 1
		}
	}
	check("labeled loops", pairs == 10, &failures)

	loops := 0
	for {
		loops += 1
		if loops == 3 {
			break
		}
	}
	check("infinite loop with break", loops == 3, &failures)

	if failures > 0 {
		fmt.printfln("%d check(s) failed", failures)
		os.exit(1)
	}
	fmt.println("All checks passed")
}
