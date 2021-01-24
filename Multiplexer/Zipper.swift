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
public class Zipper {
	public typealias OnResult<T> = (Result<T, Error>) -> Void
	public typealias OnFetch<T> = (@escaping OnResult<T>) -> Void

	private var fetchers: [OnFetch<Any>] = []

	public init() { }

	/// Add an execution block that returns a `Result<T, Error>`, where generic type T is inferred from the `onFetch` argument.
	@discardableResult
	public func add<T>(_ onFetch: @escaping OnFetch<T>) -> Self {
		fetchers.append { (onAnyResult) in
			onFetch { (result) in
				// Is this the only way to convert T to Any? The compiler doesn't seem to be happy otherwise.
				onAnyResult(result.map { $0 })
			}
		}
		return self
	}

	/// Add a multiplexer object to the zipper. This multiplexer's `request(completion:)` will be called as part of the zipper chain.
	@discardableResult
	public func add<T: Codable>(_ multiplexer: Multiplexer<T>) -> Self {
		return add { (onResult) in
			multiplexer.request(completion: onResult)
		}
	}

	/// Add a multiplexer map object to the zipper. This multiplexer's `request(key:completion:)` will be called as part of the zipper chain.
	@discardableResult
	public func add<K: MuxKey, T: Codable>(key: K, _ multiplexer: MultiplexerMap<K, T>) -> Self {
		return add { (onResult) in
			multiplexer.request(key: key, completion: onResult)
		}
	}

	/// Add a media loader (ImageLoader or MediaLoader) to the zipper. This loader's `request(url:completion:)` will be called as part of the zipper chain.
	@discardableResult
	public func add<T>(url: URL, _ mediaLoader: CachingLoaderBase<T>) -> Self {
		return add { (onResult) in
			mediaLoader.request(url: url, completion: onResult)
		}
	}

	/// Execute all the blocks added so far and wait for the results. The results will be delivered at once into the `completion` block in the form of an array of `Result<Any, Error>`, where the order of objects is the same as the order of the `add()` method calls. This is not type safe, which means you will have to typecast each result accordingly.
	/// Because Zipper stores all the multiplexer objects and blocks, it is possible to reuse the same instance with multiple calls to `sync()` though you should be careful with cyclic references in your blocks. It is probably best to chain a call to the Zipper constructor, then `add(...)` and `sync(...)` in one statement without retaining the Zipper instance.
	public func sync(completion: @escaping (_ results: [Result<Any, Error>]) -> Void) {
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



extension Zipper {

	// Experimental type-safe zipper constructors

	public static func sync<A, B>(
		_ a: @escaping OnFetch<A>,
		_ b: @escaping OnFetch<B>,
		onResults: @escaping (
			Result<A, Error>,
			Result<B, Error>) -> Void) {
		Zipper().add(a).add(b).sync { (results) in
			onResults(
				results[0].map { $0 as! A },
				results[1].map { $0 as! B }
			)
		}
	}


	public static func sync<A, B, C>(
		_ a: @escaping OnFetch<A>,
		_ b: @escaping OnFetch<B>,
		_ c: @escaping OnFetch<C>,
		onResults: @escaping (
			Result<A, Error>,
			Result<B, Error>,
			Result<C, Error>) -> Void) {
		Zipper().add(a).add(b).add(c).sync { (results) in
			onResults(
				results[0].map { $0 as! A },
				results[1].map { $0 as! B },
				results[2].map { $0 as! C }
			)
		}
	}


	public static func sync<A, B, C, D>(
		_ a: @escaping OnFetch<A>,
		_ b: @escaping OnFetch<B>,
		_ c: @escaping OnFetch<C>,
		_ d: @escaping OnFetch<D>,
		onResults: @escaping (
			Result<A, Error>,
			Result<B, Error>,
			Result<C, Error>,
			Result<D, Error>) -> Void) {
		Zipper().add(a).add(b).add(c).add(d).sync { (results) in
			onResults(
				results[0].map { $0 as! A },
				results[1].map { $0 as! B },
				results[2].map { $0 as! C },
				results[3].map { $0 as! D }
			)
		}
	}


	public static func sync<A, B, C, D, E>(
		_ a: @escaping OnFetch<A>,
		_ b: @escaping OnFetch<B>,
		_ c: @escaping OnFetch<C>,
		_ d: @escaping OnFetch<D>,
		_ e: @escaping OnFetch<E>,
		onResults: @escaping (
			Result<A, Error>,
			Result<B, Error>,
			Result<C, Error>,
			Result<D, Error>,
			Result<E, Error>) -> Void) {
		Zipper().add(a).add(b).add(c).add(d).add(e).sync { (results) in
			onResults(
				results[0].map { $0 as! A },
				results[1].map { $0 as! B },
				results[2].map { $0 as! C },
				results[3].map { $0 as! D },
				results[4].map { $0 as! E }
			)
		}
	}
}
