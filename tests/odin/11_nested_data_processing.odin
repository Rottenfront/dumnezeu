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

Category :: enum {
	Tool,
	Material,
	Food,
}

Item :: struct {
	name:     string,
	category: Category,
	quantity: int,
	price:    f64,
}

Warehouse :: struct {
	name:  string,
	items: [dynamic]Item,
}

Company :: struct {
	warehouses: [dynamic]Warehouse,
}

Summary :: struct {
	total_quantity: int,
	total_value:    f64,
	by_category:    [Category]int,
}

add_item :: proc(w: ^Warehouse, item: Item) {
	append(&w.items, item)
}

summarize :: proc(company: ^Company) -> Summary {
	summary: Summary
	for warehouse in company.warehouses {
		for item in warehouse.items {
			summary.total_quantity += item.quantity
			summary.total_value += f64(item.quantity) * item.price
			summary.by_category[item.category] += item.quantity
		}
	}
	return summary
}

restock :: proc(company: ^Company, name: string, amount: int) -> int {
	updated := 0
	for &warehouse in company.warehouses {
		for &item in warehouse.items {
			if item.name == name {
				item.quantity += amount
				updated += 1
			}
		}
	}
	return updated
}

destroy :: proc(company: ^Company) {
	for warehouse in company.warehouses {
		delete(warehouse.items)
	}
	delete(company.warehouses)
}

main :: proc() {
	failures := 0

	company: Company
	defer destroy(&company)

	north := Warehouse {
		name = "north",
	}
	add_item(&north, Item{"hammer", .Tool, 10, 12.5})
	add_item(&north, Item{"nails", .Material, 500, 0.25})

	south := Warehouse {
		name = "south",
	}
	add_item(&south, Item{"saw", .Tool, 4, 20.0})
	add_item(&south, Item{"bread", .Food, 30, 2.0})
	add_item(&south, Item{"hammer", .Tool, 5, 12.5})

	append(&company.warehouses, north, south)
	check("warehouse count", len(company.warehouses) == 2, &failures)
	check("item counts", len(company.warehouses[0].items) == 2 && len(company.warehouses[1].items) == 3, &failures)
	check("nested read", company.warehouses[1].items[1].name == "bread", &failures)

	summary := summarize(&company)
	fmt.printfln("quantity=%d value=%.2f", summary.total_quantity, summary.total_value)
	check("total quantity", summary.total_quantity == 549, &failures)
	check("total value", summary.total_value == 125.0 + 125.0 + 80.0 + 60.0 + 62.5, &failures)
	check("tool quantity", summary.by_category[.Tool] == 19, &failures)
	check("material quantity", summary.by_category[.Material] == 500, &failures)
	check("food quantity", summary.by_category[.Food] == 30, &failures)

	updated := restock(&company, "hammer", 5)
	check("restock matches across warehouses", updated == 2, &failures)
	check("restock mutates nested items", company.warehouses[0].items[0].quantity == 15, &failures)
	check("restock second warehouse", company.warehouses[1].items[2].quantity == 10, &failures)
	check("restock unknown item", restock(&company, "anvil", 1) == 0, &failures)

	after := summarize(&company)
	check("tool quantity after restock", after.by_category[.Tool] == 29, &failures)

	expensive := 0
	for warehouse in company.warehouses {
		for item in warehouse.items {
			if item.price >= 10 {
				expensive += 1
			}
		}
	}
	check("filter by price", expensive == 3, &failures)

	if failures > 0 {
		fmt.printfln("%d check(s) failed", failures)
		os.exit(1)
	}
	fmt.println("All checks passed")
}
