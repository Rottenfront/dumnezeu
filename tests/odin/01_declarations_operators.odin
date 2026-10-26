package main

import "core:fmt"
import "core:os"

LIMIT :: 100

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

	count: int = 10
	inferred := 7
	width, height := 640, 480
	ratio := 2.5
	name: string = "Odin"
	flag := true
	hex_value := 0xFF
	binary_value := 0b1010
	octal_value := 0o17
	letter := 'A'

	check("typed declaration", count == 10, &failures)
	check("inferred declaration", inferred == 7, &failures)
	check("multiple declaration", width == 640 && height == 480, &failures)
	check("float declaration", ratio == 2.5, &failures)
	check("string length", len(name) == 4, &failures)
	check("bool declaration", flag, &failures)
	check("hex literal", hex_value == 255, &failures)
	check("binary literal", binary_value == 10, &failures)
	check("octal literal", octal_value == 15, &failures)
	check("rune literal", letter == 65, &failures)
	check("constant declaration", LIMIT == 100, &failures)

	check("addition", count + inferred == 17, &failures)
	check("subtraction", count - inferred == 3, &failures)
	check("multiplication", count * inferred == 70, &failures)
	check("division", count / 3 == 3, &failures)
	check("remainder", count % 3 == 1, &failures)
	check("float division", ratio / 2 == 1.25, &failures)
	check("unary minus", -count == -10, &failures)
	check("logical not", !flag == false, &failures)
	check("comparison", count > inferred && inferred <= 7 && count != inferred, &failures)
	check("logical or", count < 0 || inferred == 7, &failures)
	check("bitwise and", (hex_value & 0x0F) == 15, &failures)
	check("bitwise or", (binary_value | 0b0101) == 15, &failures)
	check("bitwise xor", (binary_value ~ 0b0110) == 12, &failures)
	check("and-not", (hex_value &~ 0xF0) == 15, &failures)
	check("shift left", (1 << 4) == 16, &failures)
	check("shift right", (256 >> 4) == 16, &failures)
	check("precedence", 2 + 3 * 4 == 14 && (2 + 3) * 4 == 20, &failures)
	check("cast", cast(f64)count / 4 == 2.5, &failures)

	if failures > 0 {
		fmt.printfln("%d check(s) failed", failures)
		os.exit(1)
	}
	fmt.println("All checks passed")
}
