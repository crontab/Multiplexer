//
//  Zipper.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 27/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


///
/// `Zipper` allows to combine two or more parallel asynchronous requests into one and receive the results from all of them at once, when they become available. Zipper supports Multiplexer, MultiplexerMap, ImageLoader, MediaLoader, as well as arbitrary execution blocks to be synchronized in a single operation. The results are not type safe in this implementation so it is up to you to properly typecast the objects in the final `sync()` call.
/// Zipper does not require its instance to be retained explicitly, i.e. you can chain the Zipper constructor with any number of `add()` methods and the final `sync()` in one Swift statement.
/// See README.md for more information and examples.
///
class Zipper {
	typealias OnResult<T> = (Result<T, Error>) -> Void
	typealias OnFetch<T> = (@escaping OnResult<T>) -> Void

	private var fetchers: [OnFetch<Any>] = []

	/// Add an execution block that returns a `Result<Any, Error>`
	func add(_ onFetch: @escaping OnFetch<Any>) -> Self {
		fetchers.append(onFetch)
		return self
	}

	/// Add an execution block that returns a `Result<T, Error>`, where generic type T is inferred from the `type` argument. This is useful when the result type can not be inferred automatically from the block definition.
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

	/// Add a multiplexer object to the zipper. This multiplexer's `request(completion:)` will be called as part of the zipper chain.
	func add<T: Codable>(_ multiplexer: Multiplexer<T>) -> Self {
		return add(type: T.self) { (onResult) in
			multiplexer.request(completion: onResult)
		}
	}

	/// Add a multiplexer map object to the zipper. This multiplexer's `request(key:completion:)` will be called as part of the zipper chain.
	func add<T: Codable>(key: String, _ multiplexer: MultiplexerMap<T>) -> Self {
		return add(type: T.self) { (onResult) in
			multiplexer.request(key: key, completion: onResult)
		}
	}

	/// Add a media loader (ImageLoader or MediaLoader) to the zipper. This loader's `request(url:completion:)` will be called as part of the zipper chain.
	func add<T: AnyObject>(url: URL, _ mediaLoader: CachingLoaderBase<T>) -> Self {
		return add(type: T.self) { (onResult) in
			mediaLoader.request(url: url, completion: onResult)
		}
	}

	/// Execute all the blocks added so far and wait for the results. The results will be delivered at once into the `completion` block in the form of an array of `Result<Any, Error>`, where the order of objects is the same as the order of the `add()` method calls. This is not type safe, which means you will have to typecast each result accordingly.
	/// Because Zipper stores all the multiplexer objects and blocks, it is possible to reuse the same instance with multiple calls to `sync()` though you should be careful with cyclic references in your blocks. It is probably best to chain a call to the Zipper constructor, then `add(...)` and `sync(...)` in one statement without retaining the Zipper instance.
	func sync(completion: @escaping (_ results: [Result<Any, Error>]) -> Void) {
		guard !fetchers.isEmpty else {
			completion([])
			return
		}
		var results: [Result<Any, Error>] = Array(repeating: .success(0), count: fetchers.count)
		var resultCount = 0
		for i in fetchers.indices {
			fetchers[i]({ result in
				results[i] = result
				resultCount += 1
				if resultCount == results.count {
					completion(results)
				}
			})
		}
	}
}
