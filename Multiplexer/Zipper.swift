//
//  Zipper.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 27/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


class Zipper {
	typealias OnResult<T> = (Result<T, Error>) -> Void
	typealias OnFetch<T> = (_ onResult: @escaping OnResult<T>) -> Void

	private var fetchers: [OnFetch<Any>] = []

	func add(_ onFetch: @escaping OnFetch<Any>) -> Self {
		fetchers.append(onFetch)
		return self
	}

	func add<T>(type: T.Type, _ onFetch: @escaping OnFetch<T>) -> Self {
		return add { (onAnyResult) in
			onFetch { (result) in
				switch result {
				case .failure(let error):
					onAnyResult(.failure(error))
				case .success(let value):
					onAnyResult(.success(value))
				}
			}
		}
	}

	func add<T: Codable>(refresh: Bool, multiplexer: Multiplexer<T>) -> Self {
		return add(type: T.self) { (onResult) in
			multiplexer.request(refresh: refresh, completion: onResult)
		}
	}

	func add<T: Codable>(refresh: Bool, key: String, multiplexer: MultiplexerMap<T>) -> Self {
		return add(type: T.self) { (onResult) in
			multiplexer.request(refresh: refresh, key: key, completion: onResult)
		}
	}

	func sync(completion: @escaping (_ results: [Result<Any, Error>]) -> Void) {
		var results: [Result<Any, Error>] = []
		fetchers.forEach { fetcher in
			fetcher { result in
				results.append(result)
				if results.count == self.fetchers.count {
					completion(results)
					self.fetchers = []
				}
			}
		}
	}
}
