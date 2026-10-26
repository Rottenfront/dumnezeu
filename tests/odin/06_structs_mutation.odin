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

Rectangle :: struct {
	origin: Point,
	size:   Point,
	label:  string,
}

area :: proc(r: Rectangle) -> int {
	return r.size.x * r.size.y
}

grow_by_value :: proc(r: Rectangle) -> Rectangle {
	copy := r
	copy.size.x += 10
	return copy
}

grow_in_place :: proc(r: ^Rectangle, dx, dy: int) {
	r.size.x += dx
	r.size.y += dy
}

main :: proc() {
	failures := 0

	p := Point{3, 4}
	check("positional literal", p.x == 3 && p.y == 4, &failures)

	named := Point {
		y = 9,
		x = 1,
	}
	check("named literal", named.x == 1 && named.y == 9, &failures)

	zero: Point
	check("zero value", zero.x == 0 && zero.y == 0, &failures)

	p.x = 10
	p.y += 5
	check("field mutation", p.x == 10 && p.y == 9, &failures)

	box := Rectangle {
		origin = Point{0, 0},
		size   = Point{640, 480},
		label  = "screen",
	}
	check("nested field read", box.size.x == 640 && box.size.y == 480, &failures)
	check("area", area(box) == 307200, &failures)

	box.size.x = 800
	box.size.y -= 80
	check("nested mutation", box.size.x == 800 && box.size.y == 400, &failures)

	grown := grow_by_value(box)
	check("copy is modified", grown.size.x == 810, &failures)
	check("original is unchanged", box.size.x == 800, &failures)

	grow_in_place(&box, 5, 5)
	check("pointer mutation", box.size.x == 805 && box.size.y == 405, &failures)

	alias := box
	alias.label = "alias"
	check("struct assignment copies", box.label == "screen" && alias.label == "alias", &failures)

	check("struct equality", Point{1, 2} == Point{1, 2} && Point{1, 2} != Point{2, 1}, &failures)

	if failures > 0 {
		fmt.printfln("%d check(s) failed", failures)
		os.exit(1)
	}
	fmt.println("All checks passed")
}
