//
//  Multiplexer.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 26/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


let STANDARD_TTL: TimeInterval = 30 * 60


internal class MultiplexFetcher<T: Codable> {
	typealias OnResult = (Result<T, Error>) -> Void
	typealias OnFetch = (@escaping OnResult) -> Void

	internal var completions: [OnResult] = []
	internal var completionTime: TimeInterval?
	internal var previousValue: T?

	internal func resultAvailable(ttl: TimeInterval) -> Bool {
		guard let completionTime = completionTime else {
			return false
		}
		return Date().timeIntervalSinceReferenceDate <= completionTime + ttl
	}

	internal func append(completion: @escaping OnResult) -> Bool {
		completions.append(completion)
		return completions.count > 1
	}

	internal func complete(result: Result<T, Error>) {
		while !completions.isEmpty {
			completions.removeFirst()(result)
		}
	}

	func clearMemory() {
		completionTime = nil
		previousValue = nil
	}
}


class MultiplexerBase<T: Codable, C: Cacher>: MultiplexFetcher<T> {

	init(onFetch: @escaping OnFetch) {
		self.onFetch = onFetch
	}

	func request(refresh: Bool, completion: @escaping OnResult) {

		// If the previous result is available in memory and is not expired, return straight away:
		if !refresh && resultAvailable(ttl: Self.timeToLive), let previousValue = previousValue {
			completion(.success(previousValue))
			return
		}

		// Append the completion block to the list of blocks to be notified when the result is available; fetch the object only if this is the first such completion block
		if append(completion: completion) {
			return
		}

		// Call the abstract method that does the job of retrieving the object, presumably asynchronously; store the result in cache for subsequent use
		onFetch { (newResult) in
			switch newResult {

			case .success(let newValue):
				self.completionTime = Date().timeIntervalSinceReferenceDate
				self.previousValue = newValue
				C.saveToCache(newValue, key: Self.cacheKey, domain: nil)
				self.complete(result: newResult)

			case .failure(let error):
				if Self.useCachedResultOn(error: error), let cachedValue = self.previousValue ?? C.loadFromCache(key: Self.cacheKey, domain: nil) {
					self.previousValue = cachedValue
					self.complete(result: .success(cachedValue))
				}
				else {
					self.completionTime = nil
					self.previousValue = nil
					self.complete(result: newResult)
				}
			}
		}
	}

	func clear() {
		clearMemory()
		C.clearCache(key: Self.cacheKey, domain: nil)
	}

	class func useCachedResultOn(error: Error) -> Bool { error.isConnectivityError }

	class var timeToLive: TimeInterval { STANDARD_TTL }

	class var cacheKey: String { String(describing: T.self) }

	private let onFetch: OnFetch
}


typealias Multiplexer<T: Codable> = MultiplexerBase<T, JSONDiskCacher<T>>
