//
//  Multiplexer.swift
//  Multiplexer
//
//  Created by Hovik Melikyan on 26/09/2019.
//  Copyright © 2019 Hovik Melikyan. All rights reserved.
//

import Foundation


typealias Multiplexer<T: Codable> = MultiplexerBase<T, JSONDiskCacher<T>>


let STANDARD_TTL: TimeInterval = 30 * 60


internal class MultiplexFetcher<T: Codable> {
	typealias OnResult = (Result<T, Error>) -> Void
	typealias OnFetch = (@escaping OnResult) -> Void

	internal var completions: [OnResult] = []
	internal var completionTime: TimeInterval = 0
	internal var previousValue: T?

	internal func isExpired(ttl: TimeInterval) -> Bool {
		return Date().timeIntervalSinceReferenceDate > completionTime + ttl
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
		completionTime = 0
		previousValue = nil
	}
}


class MultiplexerBase<T: Codable, C: Cacher>: MultiplexFetcher<T>, MuxRepositoryProtocol {

	init(onFetch: @escaping OnFetch) {
		self.onFetch = onFetch
	}

	func request(refresh: Bool, completion: @escaping OnResult) {

		// If the previous result is available in memory and is not expired, return straight away:
		if !refresh, let previousValue = previousValue, !isExpired(ttl: Self.timeToLive) {
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
				self.complete(result: newResult)

			case .failure(let error):
				if Self.useCachedResultOn(error: error), let cachedValue = self.previousValue ?? C.loadFromCache(key: Self.cacheKey, domain: nil) {
					// Keep the loaded value in memory but don't touch completionTime so that a new attempt at retrieving can be made next time
					self.previousValue = cachedValue
					self.complete(result: .success(cachedValue))
				}
				else {
					self.clearMemory()
					self.complete(result: newResult)
				}
			}
		}
	}

	func clear() {
		clearMemory()
		C.clearCache(key: Self.cacheKey, domain: nil)
	}

	func flush() {
		if let previousValue = previousValue {
			C.saveToCache(previousValue, key: Self.cacheKey, domain: nil)
		}
	}

	class func useCachedResultOn(error: Error) -> Bool { error.isConnectivityError }

	class var timeToLive: TimeInterval { STANDARD_TTL }

	class var cacheKey: String { String(describing: T.self) }

	private let onFetch: OnFetch
}
