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

sum :: proc(values: []int) -> int {
	total := 0
	for value in values {
		total += value
	}
	return total
}

double_all :: proc(values: []int) {
	for _, i in values {
		values[i] *= 2
	}
}

main :: proc() {
	failures := 0

	fixed: [3]int = {10, 20, 30}
	inferred := [?]int{1, 2, 3, 4}
	zeroed: [5]int

	check("fixed length", len(fixed) == 3, &failures)
	check("inferred length", len(inferred) == 4, &failures)
	check("zero initialized", zeroed[0] == 0 && zeroed[4] == 0, &failures)
	check("index read", fixed[0] == 10 && fixed[2] == 30, &failures)

	fixed[1] = 25
	check("index write", fixed[1] == 25, &failures)

	whole: []int = fixed[:]
	check("full slice length", len(whole) == 3, &failures)

	middle := inferred[1:3]
	check("sub slice", len(middle) == 2 && middle[0] == 2 && middle[1] == 3, &failures)

	head := inferred[:2]
	tail := inferred[2:]
	check("open-ended slices", len(head) == 2 && len(tail) == 2 && tail[0] == 3, &failures)

	check("sum of array slice", sum(fixed[:]) == 65, &failures)
	check("sum of sub slice", sum(inferred[1:]) == 9, &failures)

	whole[0] = 11
	check("slice aliases array", fixed[0] == 11, &failures)

	double_all(inferred[:])
	check("mutation through slice", inferred == [4]int{2, 4, 6, 8}, &failures)

	copied := fixed
	copied[0] = 99
	check("array assignment copies", fixed[0] == 11 && copied[0] == 99, &failures)

	grid: [2][3]int
	for row in 0 ..< 2 {
		for col in 0 ..< 3 {
			grid[row][col] = row * 3 + col
		}
	}
	check("nested array", grid[1][2] == 5 && grid[0][1] == 1, &failures)

	literal := []int{4, 5, 6}
	check("slice literal", len(literal) == 3 && sum(literal) == 15, &failures)

	if failures > 0 {
		fmt.printfln("%d check(s) failed", failures)
		os.exit(1)
	}
	fmt.println("All checks passed")
}
