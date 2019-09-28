//
//  MultiplexerMap.swift
//  MultiplexerMap
//
//  Created by Hovik Melikyan on 26/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


class MultiplexerMapBase<T: Codable, C: Cacher> {
	typealias K = String
	typealias OnResult = (Result<T, Error>) -> Void
	typealias OnKeyFetch = (K, @escaping OnResult) -> Void

	init(onKeyFetch: @escaping OnKeyFetch) {
		self.onKeyFetch = onKeyFetch
	}


	internal func request(refresh: Bool, key: K, completion: @escaping OnResult) {
		let fetcher = fetcherForKey(key)

		// If the previous result is available in memory and is not expired, return straight away:
		if !refresh && fetcher.resultAvailable(ttl: Self.timeToLive), let previousValue = fetcher.previousValue {
			completion(.success(previousValue))
			return
		}

		// Append the completion block to the list of blocks to be notified when the result is available; fetch the object only if this is the first such completion block
		if fetcher.append(completion: completion) {
			return
		}

		// Call the abstract method that does the job of retrieving the object, presumably asynchronously; store the result in cache for subsequent use
		onKeyFetch(key) { (newResult) in
			switch newResult {

			case .success(let newValue):
				fetcher.completionTime = Date().timeIntervalSinceReferenceDate
				fetcher.previousValue = newValue
				C.saveToCache(newValue, key: key, domain: Self.cacheDomain)
				fetcher.complete(result: newResult)

			case .failure(let error):
				if Self.useCachedResultOn(error: error), let cachedValue = fetcher.previousValue ?? C.loadFromCache(key: key, domain: Self.cacheDomain) {
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
		C.clearCache(key: key, domain: Self.cacheDomain)
	}

	func clear() {
		clearMemory()
		C.clearCacheMap(domain: Self.cacheDomain)
	}

	class func useCachedResultOn(error: Error) -> Bool { error.isConnectivityError }

	class var timeToLive: TimeInterval { STANDARD_TTL }

	class var cacheDomain: String { String(describing: T.self) }

	private typealias Fetcher = MultiplexFetcher<T>

	private let onKeyFetch: OnKeyFetch
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


typealias MultiplexerMap<T: Codable> = MultiplexerMapBase<T, JSONDiskCacher<T>>
