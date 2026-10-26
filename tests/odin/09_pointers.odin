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

Point :: struct {
	x, y: int,
}

Node :: struct {
	value: int,
	next:  ^Node,
}

move :: proc(point: ^Point, dx, dy: int) {
	point^.x += dx
	point.y += dy
}

swap :: proc(a, b: ^int) {
	a^, b^ = b^, a^
}

list_sum :: proc(head: ^Node) -> int {
	total := 0
	for node := head; node != nil; node = node.next {
		total += node.value
	}
	return total
}

main :: proc() {
	failures := 0

	value := 10
	pointer: ^int = &value
	check("address-of and deref", pointer^ == 10, &failures)

	pointer^ = 20
	check("write through pointer", value == 20, &failures)

	pointer^ += 5
	check("compound write through pointer", value == 25, &failures)

	empty: ^int
	check("nil pointer", empty == nil && pointer != nil, &failures)

	a, b := 1, 2
	swap(&a, &b)
	check("swap via pointers", a == 2 && b == 1, &failures)

	point := Point{10, 20}
	move(&point, 3, -2)
	check("struct pointer mutation", point.x == 13 && point.y == 18, &failures)

	point_ptr := &point
	point_ptr.x = 100
	check("implicit field deref", point.x == 100 && point_ptr^.x == 100, &failures)

	numbers := [3]int{1, 2, 3}
	first := &numbers[0]
	first^ = 50
	check("pointer to array element", numbers[0] == 50, &failures)

	third := Node{value = 3}
	second := Node {
		value = 2,
		next  = &third,
	}
	head := Node {
		value = 1,
		next  = &second,
	}
	check("linked list sum", list_sum(&head) == 6, &failures)
	check("chained deref", head.next^.next^.value == 3, &failures)

	head.next.value += 10
	check("mutation through chain", second.value == 12 && list_sum(&head) == 16, &failures)
	check("end of list is nil", third.next == nil, &failures)

	heap := new(Point)
	defer free(heap)
	heap^ = Point{7, 8}
	check("heap allocated value", heap.x == 7 && heap.y == 8, &failures)

	if failures > 0 {
		fmt.printfln("%d check(s) failed", failures)
		os.exit(1)
	}
	fmt.println("All checks passed")
}
