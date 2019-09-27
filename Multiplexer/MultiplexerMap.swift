//
//  MultiplexerMap.swift
//  MultiplexerMap
//
//  Created by Hovik Melikyan on 26/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


class MultiplexerMap<T: Codable> {
	typealias K = String
	typealias Completion = (Result<T, Error>) -> Void
	typealias OnKeyFetch = (K, @escaping Completion) -> Void

	private let onKeyFetch: OnKeyFetch

	init(onKeyFetch: @escaping OnKeyFetch) {
		self.onKeyFetch = onKeyFetch
	}


	internal func request(refresh: Bool, key: K, completion: @escaping Completion) {
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
				Self.saveToCache(newValue, key: key)
				fetcher.complete(result: newResult)

			case .failure(let error):
				if Self.useCachedResultOn(error: error), let cachedValue = fetcher.previousValue ?? Self.loadFromCache(key: key) {
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
		Self.clearCache(key: key)
	}

	func clear() {
		clearMemory()
		Self.clearCache()
	}

	// Caching: protected

	class func useCachedResultOn(error: Error) -> Bool { error.isConnectivityError }

	class var timeToLive: TimeInterval { STANDARD_TTL }

	class var cacheDomain: String? { String(describing: T.self) }

	class func loadFromCache(key: K) -> T? {
		if let cacheFileURL = cacheFileURL(key: key, create: false) {
			return try? jsonDecoder.decode(T.self, from: Data(contentsOf: cacheFileURL))
		}
		return nil
	}

	class func saveToCache(_ result: T, key: K) {
		if let cacheFileURL = cacheFileURL(key: key, create: true) {
			DLOG("MultiplexerMap: storing to \(cacheFileURL)")
			try! jsonEncoder.encode(result).write(to: cacheFileURL, options: .atomic)
		}
	}

	class func clearCache(key: K) {
		FileManager.removeRecursively(cacheFileURL(key: key, create: false))
	}

	class func clearCache() {
		FileManager.removeRecursively(cacheDirURL(create: false))
	}

	class func cacheFileURL(key: K, create: Bool) -> URL? {
		return cacheDirURL(create: create)?.appendingPathComponent(key.description).appendingPathExtension("json")
	}

	class func cacheDirURL(create: Bool) -> URL? {
		if let cacheDomain = Self.cacheDomain {
			precondition(!cacheDomain.isEmpty)
			return FileManager.cacheDirectory(subDirectory: "Mux/" + cacheDomain + ".Map", create: create)
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
