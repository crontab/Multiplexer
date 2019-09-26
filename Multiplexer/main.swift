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


final class Test: Multiplexer<Obj> {
	static var shared: Test = { Test() }()

	func onFetch(onResult: @escaping (Result<Obj, Error>) -> Void) {
		DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
			onResult(.success(Obj(id: "0", name: "HM")))
		}
	}
}


Test.shared.request(refresh: false) { (result) in
	print(result)
	Test.shared.request(refresh: false) { (result) in
		print(result)
	}
}


final class TestMap: MultiplexerMap<String, Obj> {
	static var shared: TestMap = TestMap()

	func onFetch(key: String, onResult: @escaping (Result<Obj, Error>) -> Void) {
		DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
			onResult(.success(Obj(id: key, name: "User \(key)")))
		}
	}
}

TestMap.shared.request(refresh: false, key: "1") { (result) in
	print(result)
	TestMap.shared.request(refresh: false, key: "1") { (result) in
		print(result)
		TestMap.shared.request(refresh: false, key: "2") { (result) in
			print(result)
		}
	}
}


RunLoop.main.run()
