//
//  main.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 25/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


internal protocol MultiplexerMapBaseProtocol {
	associatedtype T: Codable
	associatedtype K: Hashable
	typealias Completion = (Result<T, Error>) -> Void
	typealias OnFetch = (K, @escaping Completion) -> Void

	func request(refresh: Bool, key: K, completion: @escaping Completion, onFetch: @escaping OnFetch)
}



class MultiplexerMap<T: Codable> {

	private class SingleFetcher: MultiplexerBase<T> {
	}
}


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

struct Obj: Codable {
	var id: String
	var name: String
}


class Test: Multiplexer<Obj> {
	func onFetch(onResult: @escaping (Result<Obj, Error>) -> Void) {
		DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
			onResult(.success(Obj(id: "1", name: "HM")))
		}
	}
}


let m = Test()

m.request(refresh: false) { (result) in
	print(result)
	m.request(refresh: false) { (result) in
		print(result)
	}
}

RunLoop.main.run()
