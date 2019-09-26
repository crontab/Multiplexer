//
//  MultiplexerMap.swift
//  MultiplexerMap
//
//  Created by Hovik Melikyan on 26/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


typealias MuxKey = String // for various reasons it better always be a string


internal protocol MultiplexerMapBaseProtocol {
	associatedtype T: Codable
	typealias K = MuxKey
	typealias Completion = (Result<T, Error>) -> Void
	typealias OnKeyFetch = (K, @escaping Completion) -> Void

	func request(refresh: Bool, key: K, completion: @escaping Completion, onFetch: @escaping OnKeyFetch)
}


class MultiplexerMapBase<T: Codable>: MultiplexerMapBaseProtocol {
	typealias Completion = (Result<T, Error>) -> Void
	typealias OnKeyFetch = (K, @escaping Completion) -> Void

	internal func request(refresh: Bool, key: K, completion: @escaping Completion, onFetch: @escaping OnKeyFetch) {
		let fetcher = fetcherForKey(key)

		// If the previous result is available in memory and is not expired, return straight away:
		if !refresh && fetcher.resultAvailable(ttl: timeToLive), let previousValue = fetcher.previousValue {
			completion(.success(previousValue))
			return
		}

		// Append the completion block to the list of blocks to be notified when the result is available; fetch the object only if this is the first such completion block
		if fetcher.append(completion: completion) {
			return
		}

		// Call the abstract method that does the job of retrieving the object, presumably asynchronously; store the result in cache for subsequent use
		onFetch(key) { (newResult) in
			switch newResult {

			case .success(let newValue):
				fetcher.completionTime = Date().timeIntervalSinceReferenceDate
				fetcher.previousValue = newValue
				self.saveToCache(newValue, key: key)
				fetcher.complete(result: newResult)

			case .failure(let error):
				if self.useCachedResultOn(error: error), let cachedValue = fetcher.previousValue ?? self.loadFromCache(key: key) {
					fetcher.previousValue = cachedValue
					fetcher.complete(result: .success(cachedValue))
				}
				else {
					fetcher.completionTime = nil
					fetcher.previousValue = nil
					fetcher.complete(result: newResult)
				}
			}
		}
	}

	func clearMemory(key: K) {
		fetcherMap.removeValue(forKey: key)
	}

	func clearMemory() {
		fetcherMap = [:]
	}

	func clear(key: K) {
		clearMemory(key: key)
		clearCache(key: key)
	}

	func clear() {
		clearMemory()
		clearCache()
	}

	// Caching: protected

	func useCachedResultOn(error: Error) -> Bool { error.isConnectivityError }

	var timeToLive: TimeInterval { STANDARD_TTL }

	var cacheDomain: String? { String(describing: type(of: self)) }

	func loadFromCache(key: K) -> T? {
		if let cacheFileURL = cacheFileURL(key: key, create: false) {
			return try? jsonDecoder.decode(T.self, from: Data(contentsOf: cacheFileURL))
		}
		return nil
	}

	func saveToCache(_ result: T, key: K) {
		if let cacheFileURL = cacheFileURL(key: key, create: true) {
			DLOG("MultiplexerMap: storing to \(cacheFileURL)")
			try! jsonEncoder.encode(result).write(to: cacheFileURL, options: .atomic)
		}
	}

	func clearCache(key: K) {
		FileManager.removeRecursively(cacheFileURL(key: key, create: false))
	}

	func clearCache() {
		FileManager.removeRecursively(cacheDirURL(create: false))
	}

	func cacheFileURL(key: K, create: Bool) -> URL? {
		return cacheDirURL(create: create)?.appendingPathComponent(key.description).appendingPathExtension("json")
	}

	func cacheDirURL(create: Bool) -> URL? {
		if let cacheDomain = cacheDomain {
			precondition(!cacheDomain.isEmpty)
			return FileManager.cacheDirectory(subDirectory: "Mux/" + cacheDomain, create: create)
		}
		return nil
	}

	// Private

	private typealias Fetcher = MultiplexFetcher<T>

	private var fetcherMap: [K: Fetcher] = [:]

	private func fetcherForKey(_ key: K) -> Fetcher {
		var fetcher = fetcherMap[key]
		if fetcher == nil {
			fetcher = Fetcher()
			fetcherMap[key] = fetcher
		}
		return fetcher!
	}
}


protocol MultiplexerMapProtocol: MultiplexerMapBaseProtocol {
	// Required abstract entities:
	static var shared: Self { get }
	func onFetch(key: K, onResult: @escaping Completion)

	// Optional overrideables; see default implementations in MultiplexerMapBase
	func useCachedResultOn(error: Error) -> Bool
	var timeToLive: TimeInterval { get }
	var cacheDomain: String? { get }
}


extension MultiplexerMapProtocol {
	func request(refresh: Bool, key: K, completion: @escaping Completion) {
		request(refresh: refresh, key: key, completion: completion, onFetch: onFetch)
	}
}


typealias MultiplexerMap<T: Codable> = MultiplexerMapBase<T> & MultiplexerMapProtocol
