//
//  main.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 25/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


private func asyncAfter(_ secs: TimeInterval, execute: @escaping () -> Void) {
	DispatchQueue.main.asyncAfter(deadline: .now() + secs, execute: execute)
}


class Backend {
	static func fetch(completion: @escaping (Result<Obj, Error>) -> Void) {
		asyncAfter(1) {
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
	asyncAfter(2) {
		print("Fetching testMap")
		onResult(.success(Obj(id: key, name: "User \(key)")))
	}
}).register()


func testMultiplexers() {

	test.request { (result) in
		print(result)
		test.request { (result) in
			print(result)
			asyncAfter(2) {
				test.refresh().request { (result) in
					print(result)
				}
			}
		}
	}

//	testMap.request(key: "1") { (result) in
//		print(result)
//		testMap.request(key: "1") { (result) in
//			print(result)
//			testMap.request(key: "2") { (result) in
//				print(result)
//				MuxRepository.flushAll()
//				MuxRepository.clearAll()
//			}
//		}
//	}

	//test.clear()
	//testMap.clear()
}



func testZipper() {
	Zipper()
		.add({ (completion) in
			asyncAfter(3) {
				completion(.success("Hello"))
			}
		})
		.add(test)
		.add(key: "1", testMap)
		.sync { (results) in
			precondition(try! results[0].get() is String)
			precondition(try! results[1].get() is Obj)
			precondition(try! results[2].get() is Obj)
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
	asyncAfter(2) {
		value = 3
		// print("Update", value)
		d?.touch()
		asyncAfter(2) {
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
		asyncAfter(3) {
			print("Trying image 3")
			ImageLoader.main.request(url: URL(string: "https://i.imgur.com/QXYqnI9.jpg")!) { (result) in
				print("Image 3")
			}
		}
	}
}


// testMultiplexers()
testZipper()
// d()
// testImageLoader()


RunLoop.main.run()
