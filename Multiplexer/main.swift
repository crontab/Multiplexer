//
//  main.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 25/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


struct Obj: Codable {
	var id: String
	var name: String
}


let test = Multiplexer<Obj> { onResult in
	DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
		onResult(.success(Obj(id: "0", name: "HM")))
	}
}

let testMap = MultiplexerMap<Obj> { (key, onResult) in
	DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
		onResult(.success(Obj(id: key, name: "User \(key)")))
	}
}



/*
test.request(refresh: false) { (result) in
	print(result)
	test.request(refresh: false) { (result) in
		print(result)
	}
}


testMap.request(refresh: false, key: "1") { (result) in
	print(result)
	testMap.request(refresh: false, key: "1") { (result) in
		print(result)
		testMap.request(refresh: false, key: "2") { (result) in
			print(result)
		}
	}
}


test.clear()
testMap.clear()
*/


func z() {
	Zipper()
		.add({ (completion) in
			DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
				completion(.success("Hello"))
			}
		})
		.add(refresh: false, multiplexer: test)
		.add(refresh: false, key: "1", multiplexer: testMap)
		.sync { (results) in
			results.forEach { print($0) }
		}
}

// z()

print(Date())
var d: Debouncer<Int>?

d = Debouncer(initialValue: 1, delay: 3) { (value) in
	print(Date(), "Triggered", value)
	// d = nil
}

d?.update(newValue: 2)
print("Update", d?.value ?? "nil")
DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
	d?.update(newValue: 3)
	print("Update", d?.value ?? "nil")
	DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
		d?.update(newValue: 4)
		print("Update", d?.value ?? "nil")
	}
}

RunLoop.main.run()
