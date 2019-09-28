//
//  main.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 25/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


class Backend {
	static func fetch(completion: @escaping (Result<Obj, Error>) -> Void) {
		DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
			print("Fetching test")
			completion(.success(Obj(id: "0", name: "HM")))
		}
	}
}


struct Obj: Codable {
	var id: String
	var name: String
}


let test = Multiplexer<Obj>(onFetch: Backend.fetch).register()

let testMap = MultiplexerMap<Obj>(onKeyFetch: { (key, onResult) in
	DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
		print("Fetching testMap")
		onResult(.success(Obj(id: key, name: "User \(key)")))
	}
}).register()


func m() {

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
				MuxRepository.flushAll()
				MuxRepository.clearAll()
			}
		}
	}


	//test.clear()
	//testMap.clear()
}



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



func d() {
	print(Date())
	var d: Debouncer?
	var value: Int = 1

	d = Debouncer(delay: 3) {
		print(Date(), "Triggered", value)
		d = nil
	}

	value = 2
	// print("Update", value)
	d?.touch()
	DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
		value = 3
		// print("Update", value)
		d?.touch()
		DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
			value = 4
			// print("Update", value)
			d?.touch()
		}
	}
}


func testImageLoader() {
	ImageLoader.main.request(url: URL(string: "https://i.imgur.com/QXYqnI9.jpg")!) { (result) in
		print("Image 1")
	}
	ImageLoader.main.request(url: URL(string: "https://i.imgur.com/QXYqnI9.jpg")!) { (result) in
		print("Image 2")
		DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
			print("Trying image 3")
			ImageLoader.main.request(url: URL(string: "https://i.imgur.com/QXYqnI9.jpg")!) { (result) in
				print("Image 3")
			}
		}
	}
}


// m()
// z()
// d()

testImageLoader()


RunLoop.main.run()
