//
//  main.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 25/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


class Zipper {
	// typealias AnyResult = Result<Any, Error>
	typealias OnResult<T> = (Result<T, Error>) -> Void
	typealias Promise<T> = (_ onResult: @escaping OnResult<T>) -> Void

	private var promises: [Promise<Any>] = []
	private var results: [Any?] = []
	private var lastError: Error?

	func add<T>(type: T.Type, promise: @escaping Promise<T>) -> Self {
		promises.append(promise as! Promise<Any>)
		return self
	}

	func add<T: Codable>(refresh: Bool, multiplexer: Multiplexer<T>) -> Self {
		return add(type: T.self) { (onResult) in
			multiplexer.request(refresh: refresh, completion: onResult)
		}
	}

	func zip() {
	}
}



struct Obj: Codable {
	var id: String
	var name: String
}


let test = Multiplexer<Obj> { onResult in
	onResult(.success(Obj(id: "0", name: "HM")))
}

test.request(refresh: false) { (result) in
	print(result)
	test.request(refresh: false) { (result) in
		print(result)
	}
}


let testMap = MultiplexerMap<Obj> { (key, onResult) in
	onResult(.success(Obj(id: key, name: "User \(key)")))
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
