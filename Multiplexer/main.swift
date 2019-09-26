//
//  main.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 25/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

/*
internal protocol MultiplexerMapBaseProtocol {
	associatedtype T: Codable
	associatedtype K: Hashable
	typealias Completion = (Result<T, Error>) -> Void
	typealias OnFetch = (K, @escaping Completion) -> Void

	func request(refresh: Bool, key: K, completion: @escaping Completion, onFetch: @escaping OnFetch)
}



class MultiplexerMapBase<K: Hashable, T: Codable>: MultiplexerMapBaseProtocol {
	typealias Completion = (Result<T, Error>) -> Void
	typealias OnFetch = (K, @escaping Completion) -> Void

	internal func request(refresh: Bool, key: K, completion: @escaping Completion, onFetch: @escaping OnFetch) {
		var fetcher = map[key]
		if fetcher == nil {
			fetcher = Fetcher(parent: self)
			map[key] = fetcher
		}
		fetcher!.request(refresh: refresh, completion: completion) { (onResult) in
			onFetch(key, onResult)
		}
	}

	func clearCache(key: K) {
		map[key]?.clearCache()
	}

	func clearMemory(key: K) {
		map[key]?.clearMemory()
	}

	func clear(key: K) {
		map[key]?.clear()
	}

	func clearCache() {
		if let cacheDirURL = cacheDirURL(create: false) {
			FileManager.removeRecursively(cacheDirURL)
		}
	}

	func clearMemory() {
		map = [:]
	}

	func clear() {
		clearMemory()
		clearCache()
	}


	// Protected

	func useCachedResultOn(error: Error) -> Bool { error.isConnectivityError }
	var timeToLive: TimeInterval { STANDARD_TTL }
	var cacheDomain: String? { return String(describing: type(of: self)) }


	// Private

	private var map: [K: Fetcher] = [:]

	private func cacheDirURL(create: Bool) -> URL? {
		if let cacheDomain = cacheDomain, !cacheDomain.isEmpty {
			return FileManager.cacheDirectory(subDirectory: "Mux/" + cacheDomain, create: create)
		}
		return nil
	}

	private class Fetcher: MultiplexerBase<T> {
		private weak var parent: MultiplexerMapBase<K, T>!

		override var cacheDomain: String? { parent.cacheDomain }
		override func useCachedResultOn(error: Error) -> Bool { parent.useCachedResultOn(error: error) }
		override var timeToLive: TimeInterval { parent.timeToLive }

		init(parent: MultiplexerMapBase<K, T>) {
			self.parent = parent
		}
	}
}


protocol MultiplexerMapProtocol: MultiplexerMapBaseProtocol {
	// Required abstract entities:
	static var shared: Self { get }
	func onFetch(key: K, onResult: @escaping Completion)

	var cacheDomain: String? { get }
	func useCachedResultOn(error: Error) -> Bool
	var timeToLive: TimeInterval { get }
}


extension MultiplexerMapProtocol {
	func request(refresh: Bool, key: K, completion: @escaping Completion) {
		request(refresh: refresh, key: key, completion: completion, onFetch: onFetch)
	}
}


// typealias MultiplexerMap<T: Codable> = MultiplexerMapBase<T> & MultiplexerMapProtocol
*/


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

struct Obj: Codable {
	var id: String
	var name: String
}


final class Test: Multiplexer<Obj> {
	static var shared: Test = { Test() }()

	func onFetch(onResult: @escaping (Result<Obj, Error>) -> Void) {
		DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
			onResult(.success(Obj(id: "1", name: "HM")))
		}
	}
}


Test.shared.request(refresh: false) { (result) in
	print(result)
	Test.shared.request(refresh: false) { (result) in
		print(result)
	}
}

RunLoop.main.run()
